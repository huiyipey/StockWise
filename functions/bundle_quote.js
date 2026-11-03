const {createHash} = require('node:crypto');

// Selected units and automatic free units are kept separate so cart rows,
// order lines and inventory deductions describe the same physical quantities.
function bundleQuote(cart, inventory, {now, sellingPrice, validatePromotion, titleCase, shelfLife}) {
  const when = value => value?.toDate ? value.toDate() : new Date(value);
  const byId = new Map(inventory.map(batch => [batch.id, batch]));
  const stock = new Map(), automatic = [], issues = [], states = [];
  const sellable = batch => batch && batch.status === 'active' && when(batch.expiryAt) > now;
  const available = batch => Math.max(0, batch.quantityOnHand - (batch.quantityReserved || 0));
  for (const item of [...cart].sort((a, b) => a.batchId.localeCompare(b.batchId))) {
    const batch = byId.get(item.batchId), quantity = item.quantity;
    if (!sellable(batch) || !Number.isSafeInteger(quantity) || quantity < 1) throw Error('A product is no longer available. Refresh your cart.');
    const used = (stock.get(batch.id) || 0) + quantity;
    if (used > available(batch)) throw Error(`Not enough ${titleCase(batch.productName)} available. Please edit your cart.`);
    stock.set(batch.id, used);
    states.push({batch, quantity, normal: quantity, locked: 0, price: sellingPrice(batch), rewards: []});
  }

  const groupsFor = (quantity, price, promotion) => promotion.requirement === 'spend'
    ? Math.floor(quantity * price / promotion.thresholdSpendCents)
    : Math.floor(quantity / promotion.thresholdQuantity);
  const rewardPrice = (price, promotion) => promotion.reward === 'free' ? 0
    : promotion.reward === 'percentage' ? Math.max(1, Math.round(price * (100 - promotion.rewardPercentage) / 100))
      : Math.max(0, price - promotion.rewardAmountCents);
  const labelFor = (batch, promotion) => {
    if (promotion.label) return promotion.label;
    const buy = promotion.requirement === 'spend' ? `Spend RM ${(promotion.thresholdSpendCents / 100).toFixed(2)} on ${titleCase(batch.productName)}`
      : `Buy ${promotion.thresholdQuantity} ${titleCase(batch.productName)}`;
    const target = titleCase(promotion.targetProductName || inventory.find(item => item.productId === promotion.targetProductId)?.productName || 'Selected Items');
    const reward = promotion.reward === 'free' ? 'Free' : promotion.reward === 'percentage' ? `${promotion.rewardPercentage}% Off`
      : `RM ${(promotion.rewardAmountCents / 100).toFixed(2)} Off`;
    return `${buy}, Get ${promotion.giftQuantity} ${target} ${reward}`;
  };
  const offers = states.filter(state => state.batch.promotionEnabled && state.batch.promotion?.type === 'bundle');
  // Self offers run first. Qualifying paid units are then protected from later
  // rewards, preventing A->B->A offers from making every unit free.
  offers.sort((a, b) => Number(b.batch.promotion.targetProductId === b.batch.productId)
    - Number(a.batch.promotion.targetProductId === a.batch.productId) || a.batch.id.localeCompare(b.batch.id));
  for (const source of offers) {
    const batch = source.batch, promotion = batch.promotion, self = promotion.targetProductId === batch.productId;
    validatePromotion(promotion, batch.basePriceCents);
    const label = labelFor(batch, promotion);
    let embedded = 0, groups;
    if (self) {
      // Find the fewest paid units that cover the selected quantity together
      // with their rewards. This also handles a partly selected multi-unit gift.
      let low = 0, high = source.normal;
      while (low < high) {
        const paid = Math.floor((low + high) / 2);
        const covered = paid + groupsFor(paid, source.price, promotion) * promotion.giftQuantity;
        if (covered >= source.normal) high = paid;
        else low = paid + 1;
      }
      embedded = source.normal - low;
      groups = groupsFor(low, source.price, promotion);
    } else groups = groupsFor(source.normal, source.price, promotion);
    if (!groups) continue;
    const entitlement = groups * promotion.giftQuantity;
    const manual = [];
    if (self) {
      if (embedded) manual.push({state: source, quantity: Math.min(embedded, entitlement)});
    } else {
      let remaining = entitlement;
      for (const target of states.filter(state => state.batch.productId === promotion.targetProductId)) {
        const quantity = Math.min(remaining, target.normal - target.locked);
        if (quantity > 0) { manual.push({state: target, quantity}); remaining -= quantity; }
        if (!remaining) break;
      }
    }
    const selectedRewards = manual.reduce((sum, item) => sum + item.quantity, 0);
    let missing = promotion.reward === 'free' ? entitlement - selectedRewards : 0;
    if (promotion.reward !== 'free' && !selectedRewards) continue;
    const extra = [];
    for (const target of inventory.filter(item => item.productId === promotion.targetProductId && sellable(item))
      .sort((a, b) => when(a.expiryAt) - when(b.expiryAt) || a.id.localeCompare(b.id))) {
      if (!missing) break;
      const quantity = Math.min(missing, available(target) - (stock.get(target.id) || 0));
      if (quantity > 0) { extra.push({batch: target, quantity}); missing -= quantity; }
    }
    if (missing) {
      issues.push({sourceBatchId: batch.id, sourceProductName: titleCase(batch.productName), promotionLabel: label,
        targetProductName: titleCase(promotion.targetProductName || inventory.find(item => item.productId === promotion.targetProductId)?.productName || 'Reward product'),
        requiredQuantity: entitlement, availableQuantity: entitlement - missing,
        message: `${label} is unavailable: only ${entitlement - missing} of ${entitlement} reward units are available.`});
      continue;
    }
    for (const reward of manual) {
      reward.state.normal -= reward.quantity;
      reward.state.rewards.push({quantity: reward.quantity, price: rewardPrice(reward.state.price, promotion), sourceBatchId: batch.id, promotionLabel: label});
    }
    const usedGroups = promotion.reward === 'free' ? groups : Math.ceil(selectedRewards / promotion.giftQuantity);
    source.locked = Math.max(source.locked, promotion.requirement === 'spend'
      ? Math.ceil(usedGroups * promotion.thresholdSpendCents / source.price)
      : usedGroups * promotion.thresholdQuantity);
    for (const reward of extra) {
      stock.set(reward.batch.id, (stock.get(reward.batch.id) || 0) + reward.quantity);
      automatic.push({...reward, sourceBatchId: batch.id, promotionLabel: label});
    }
  }

  const lines = [], cartSummaries = [];
  const addLine = (batch, quantity, price, extra) => {
    if (!quantity) return;
    lines.push({batchId: batch.id, productId: batch.productId, productName: batch.productName, categoryId: batch.categoryId || 'others',
      imagePath: batch.imagePath || null, regularUnitPriceCents: batch.basePriceCents, expiryAt: when(batch.expiryAt), unitLabel: batch.unitLabel || 'unit',
      receivedAt: when(batch.receivedAt || batch.createdAt || now),
      totalShelfLifeDays: Number.isInteger(batch.totalShelfLifeDays) ? batch.totalShelfLifeDays : shelfLife(batch, now).totalShelfLifeDays,
      quantity, unitPriceCents: price, lineTotalCents: price * quantity, discountCents: Math.max(0, (sellingPrice(batch) - price) * quantity), ...extra});
  };
  for (const state of states) {
    const batch = state.batch;
    addLine(batch, state.normal, state.price, {kind: 'purchase', cartBatchId: batch.id, automaticReward: false});
    for (const reward of state.rewards) addLine(batch, reward.quantity, reward.price,
      {kind: 'bundle', cartBatchId: batch.id, automaticReward: false, sourceBatchId: reward.sourceBatchId, promotionLabel: reward.promotionLabel});
    cartSummaries.push({batchId: batch.id, quantity: state.quantity, originalTotalCents: state.quantity * state.price,
      totalCents: state.normal * state.price + state.rewards.reduce((sum, reward) => sum + reward.quantity * reward.price, 0),
      rewardQuantity: state.rewards.reduce((sum, reward) => sum + reward.quantity, 0),
      promotionLabels: [...new Set(state.rewards.map(reward => reward.promotionLabel))]});
  }
  for (const reward of automatic) addLine(reward.batch, reward.quantity, 0,
    {kind: 'bundle', cartBatchId: null, automaticReward: true, sourceBatchId: reward.sourceBatchId, promotionLabel: reward.promotionLabel});
  const subtotalCents = lines.reduce((sum, line) => sum + line.lineTotalCents, 0);
  const promotionWarnings = issues.filter(issue => {
    const source = states.find(state => state.batch.id === issue.sourceBatchId);
    return groupsFor(source.normal, source.price, source.batch.promotion) > 0;
  });
  const promotionReviewToken = promotionWarnings.length ? createHash('sha256').update(JSON.stringify({cartSummaries, promotionWarnings,
    extra: automatic.map(reward => [reward.batch.id, reward.quantity, reward.sourceBatchId]), subtotalCents})).digest('hex') : null;
  return {lines, cartSummaries, stock: [...stock].map(([id, quantity]) => ({id, quantity})), subtotalCents,
    discountCents: lines.reduce((sum, line) => sum + line.discountCents, 0), promotionWarnings, promotionReviewToken};
}

module.exports = {bundleQuote};
