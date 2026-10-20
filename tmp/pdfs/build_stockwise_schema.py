from pathlib import Path

from reportlab.graphics.shapes import Drawing, Line, Rect, String
from reportlab.lib import colors
from reportlab.lib.colors import HexColor
from reportlab.lib.enums import TA_CENTER, TA_LEFT
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import mm
from reportlab.platypus import (
    BaseDocTemplate,
    Frame,
    KeepTogether,
    PageBreak,
    PageTemplate,
    Paragraph,
    Spacer,
    Table,
    TableStyle,
)


ROOT = Path(__file__).resolve().parents[2]
OUTPUT = ROOT / "output" / "pdf" / "stockwise-firestore-schema-v1.pdf"

PAGE_W, PAGE_H = A4
MARGIN_X = 18 * mm
MARGIN_TOP = 20 * mm
MARGIN_BOTTOM = 17 * mm

GREEN = HexColor("#7EAE78")
GREEN_DARK = HexColor("#5F8C5B")
GREEN_SOFT = HexColor("#EAF3E8")
PURPLE = HexColor("#7452C6")
PURPLE_SOFT = HexColor("#F0EAFB")
INK = HexColor("#242824")
MUTED = HexColor("#6F776F")
BORDER = HexColor("#DDE4DA")
BACKGROUND = HexColor("#F5F6F3")
WARNING = HexColor("#F2A93B")
DANGER = HexColor("#F45B63")
BLUE = HexColor("#1F6F93")
WHITE = colors.white


class StockWiseDocTemplate(BaseDocTemplate):
    def __init__(self, filename):
        super().__init__(
            filename,
            pagesize=A4,
            leftMargin=MARGIN_X,
            rightMargin=MARGIN_X,
            topMargin=MARGIN_TOP,
            bottomMargin=MARGIN_BOTTOM,
            title="StockWise Firestore Schema v1 - Multi-store",
            author="StockWise",
            subject="Firebase database schema proposal for review and approval",
        )
        frame = Frame(
            self.leftMargin,
            self.bottomMargin,
            self.width,
            self.height,
            id="content",
            leftPadding=0,
            rightPadding=0,
            topPadding=0,
            bottomPadding=0,
        )
        self.addPageTemplates(PageTemplate(id="main", frames=[frame], onPage=draw_page))


def draw_page(canvas, doc):
    canvas.saveState()
    if doc.page > 1:
        canvas.setFillColor(GREEN_DARK)
        canvas.setFont("Helvetica-Bold", 8)
        canvas.drawString(MARGIN_X, PAGE_H - 11 * mm, "STOCKWISE  /  MULTI-STORE FIRESTORE SCHEMA V1")
        canvas.setStrokeColor(BORDER)
        canvas.setLineWidth(0.6)
        canvas.line(MARGIN_X, PAGE_H - 13 * mm, PAGE_W - MARGIN_X, PAGE_H - 13 * mm)
    canvas.setFillColor(MUTED)
    canvas.setFont("Helvetica", 8)
    canvas.drawString(MARGIN_X, 9 * mm, "Draft for review - no database wiring performed")
    canvas.drawRightString(PAGE_W - MARGIN_X, 9 * mm, f"Page {doc.page}")
    canvas.restoreState()


styles = getSampleStyleSheet()
styles.add(ParagraphStyle(
    name="CoverTitle",
    parent=styles["Title"],
    fontName="Helvetica-Bold",
    fontSize=31,
    leading=35,
    textColor=INK,
    alignment=TA_LEFT,
    spaceAfter=8,
))
styles.add(ParagraphStyle(
    name="CoverSub",
    parent=styles["BodyText"],
    fontName="Helvetica",
    fontSize=12,
    leading=18,
    textColor=MUTED,
    spaceAfter=16,
))
styles.add(ParagraphStyle(
    name="H1x",
    parent=styles["Heading1"],
    fontName="Helvetica-Bold",
    fontSize=22,
    leading=27,
    textColor=INK,
    spaceBefore=2,
    spaceAfter=12,
))
styles.add(ParagraphStyle(
    name="H2x",
    parent=styles["Heading2"],
    fontName="Helvetica-Bold",
    fontSize=14,
    leading=18,
    textColor=GREEN_DARK,
    spaceBefore=10,
    spaceAfter=6,
))
styles.add(ParagraphStyle(
    name="Bodyx",
    parent=styles["BodyText"],
    fontName="Helvetica",
    fontSize=9.5,
    leading=14,
    textColor=INK,
    spaceAfter=6,
))
styles.add(ParagraphStyle(
    name="Smallx",
    parent=styles["BodyText"],
    fontName="Helvetica",
    fontSize=8.2,
    leading=11.2,
    textColor=MUTED,
))
styles.add(ParagraphStyle(
    name="Callout",
    parent=styles["BodyText"],
    fontName="Helvetica-Bold",
    fontSize=10.5,
    leading=15,
    textColor=GREEN_DARK,
    spaceAfter=0,
))
styles.add(ParagraphStyle(
    name="Codex",
    parent=styles["Code"],
    fontName="Courier",
    fontSize=7.4,
    leading=10,
    textColor=INK,
    leftIndent=0,
    spaceAfter=0,
))
styles.add(ParagraphStyle(
    name="CenterSmall",
    parent=styles["Smallx"],
    alignment=TA_CENTER,
))


def pill(text, bg=GREEN_SOFT, fg=GREEN_DARK):
    t = Table([[Paragraph(text, ParagraphStyle(
        "pill-text", parent=styles["Smallx"], fontName="Helvetica-Bold", textColor=fg,
        alignment=TA_CENTER, fontSize=8.5, leading=10,
    ))]], colWidths=[52 * mm])
    t.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, -1), bg),
        ("BOX", (0, 0), (-1, -1), 0.7, fg),
        ("LEFTPADDING", (0, 0), (-1, -1), 8),
        ("RIGHTPADDING", (0, 0), (-1, -1), 8),
        ("TOPPADDING", (0, 0), (-1, -1), 5),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 5),
    ]))
    return t


def info_box(title, body, accent=GREEN):
    data = [[Paragraph(title, styles["Callout"])], [Paragraph(body, styles["Bodyx"])]]
    t = Table(data, colWidths=[PAGE_W - 2 * MARGIN_X - 12 * mm])
    t.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, -1), BACKGROUND),
        ("BOX", (0, 0), (-1, -1), 0.7, BORDER),
        ("LINEBEFORE", (0, 0), (0, -1), 4, accent),
        ("LEFTPADDING", (0, 0), (-1, -1), 10),
        ("RIGHTPADDING", (0, 0), (-1, -1), 10),
        ("TOPPADDING", (0, 0), (-1, 0), 9),
        ("BOTTOMPADDING", (0, -1), (-1, -1), 9),
    ]))
    return t


def bullet(text):
    return Paragraph(f"<font color='#5F8C5B'><b>-</b></font>  {text}", styles["Bodyx"])


def section_title(number, title, subtitle=None):
    items = [Paragraph(f"{number}. {title}", styles["H1x"])]
    if subtitle:
        items.append(Paragraph(subtitle, styles["CoverSub"]))
    return items


def collection_block(path, purpose, fields, accent=GREEN):
    field_text = "<br/>".join(fields)
    header = Table([
        [Paragraph(f"<b>{path}</b>", styles["Bodyx"]), Paragraph(purpose, styles["Smallx"])]
    ], colWidths=[68 * mm, 99 * mm])
    header.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, -1), GREEN_SOFT if accent == GREEN else PURPLE_SOFT),
        ("BOX", (0, 0), (-1, -1), 0.7, BORDER),
        ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
        ("LEFTPADDING", (0, 0), (-1, -1), 8),
        ("RIGHTPADDING", (0, 0), (-1, -1), 8),
        ("TOPPADDING", (0, 0), (-1, -1), 7),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 7),
    ]))
    body = Table([[Paragraph(field_text, styles["Codex"])]], colWidths=[167 * mm])
    body.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, -1), WHITE),
        ("BOX", (0, 0), (-1, -1), 0.7, BORDER),
        ("LEFTPADDING", (0, 0), (-1, -1), 10),
        ("RIGHTPADDING", (0, 0), (-1, -1), 10),
        ("TOPPADDING", (0, 0), (-1, -1), 8),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 8),
    ]))
    return KeepTogether([header, body, Spacer(1, 9)])


def relationship_diagram():
    w, h = 167 * mm, 145 * mm
    d = Drawing(w, h)

    def node(x, y, width, label, color=GREEN_SOFT, border=GREEN_DARK):
        d.add(Rect(x, y, width, 15 * mm, rx=5, ry=5, fillColor=color, strokeColor=border, strokeWidth=1))
        d.add(String(x + width / 2, y + 8.3 * mm, label, fontName="Helvetica-Bold", fontSize=8.5,
                     fillColor=INK, textAnchor="middle"))

    def connector(x1, y1, x2, y2, label=""):
        d.add(Line(x1, y1, x2, y2, strokeColor=BORDER, strokeWidth=1.3))
        if label:
            d.add(String((x1 + x2) / 2, (y1 + y2) / 2 + 2, label, fontName="Helvetica", fontSize=6.8,
                         fillColor=MUTED, textAnchor="middle"))

    # Three clear lanes with a tenant root above the store-scoped data.
    d.add(String(14 * mm, h - 8 * mm, "ACCOUNT", fontName="Helvetica-Bold", fontSize=8, fillColor=MUTED))
    d.add(String(65 * mm, h - 8 * mm, "STORE + COMMERCE", fontName="Helvetica-Bold", fontSize=8, fillColor=MUTED))
    d.add(String(119 * mm, h - 8 * mm, "INVENTORY", fontName="Helvetica-Bold", fontSize=8, fillColor=MUTED))

    node(8 * mm, 105 * mm, 42 * mm, "USERS")
    node(8 * mm, 72 * mm, 42 * mm, "STORE MEMBERS")
    node(8 * mm, 39 * mm, 42 * mm, "ADDRESSES")
    node(8 * mm, 6 * mm, 42 * mm, "DEVICES")

    node(62 * mm, 105 * mm, 42 * mm, "STORES", PURPLE_SOFT, PURPLE)
    node(62 * mm, 72 * mm, 42 * mm, "CARTS", PURPLE_SOFT, PURPLE)
    node(62 * mm, 39 * mm, 42 * mm, "ORDERS", PURPLE_SOFT, PURPLE)
    node(62 * mm, 6 * mm, 42 * mm, "ORDER ITEMS", PURPLE_SOFT, PURPLE)

    node(117 * mm, 105 * mm, 42 * mm, "CATEGORIES")
    node(117 * mm, 72 * mm, 42 * mm, "PRODUCTS")
    node(117 * mm, 39 * mm, 42 * mm, "INVENTORY BATCHES")
    node(117 * mm, 6 * mm, 42 * mm, "INVENTORY EVENTS")

    connector(29 * mm, 105 * mm, 29 * mm, 87 * mm, "assigned")
    connector(8 * mm, 112 * mm, 8 * mm, 46 * mm, "saves")
    connector(50 * mm, 112 * mm, 50 * mm, 13 * mm, "registers")
    connector(50 * mm, 79 * mm, 62 * mm, 112 * mm, "belongs to")
    connector(50 * mm, 112 * mm, 62 * mm, 46 * mm, "places")
    connector(83 * mm, 105 * mm, 83 * mm, 87 * mm, "owns cart")
    connector(83 * mm, 39 * mm, 83 * mm, 21 * mm, "contains")
    connector(104 * mm, 112 * mm, 117 * mm, 112 * mm, "scopes")
    connector(138 * mm, 105 * mm, 138 * mm, 87 * mm, "classifies")
    connector(138 * mm, 72 * mm, 138 * mm, 54 * mm, "stocked as")
    connector(138 * mm, 39 * mm, 138 * mm, 21 * mm, "records")
    connector(104 * mm, 79 * mm, 117 * mm, 46 * mm, "selects batch")
    connector(104 * mm, 13 * mm, 117 * mm, 46 * mm, "fulfills")
    return d


def build_story():
    story = []

    story.extend([
        Spacer(1, 22 * mm),
        pill("DRAFT FOR APPROVAL", PURPLE_SOFT, PURPLE),
        Spacer(1, 14 * mm),
        Paragraph("StockWise<br/>Multi-store Firestore Schema", styles["CoverTitle"]),
        Paragraph(
            "A review-ready, tenant-isolated database blueprint for the Android and iOS application. "
            "It covers stores, staff membership, users, expiring inventory, promotions, carts, orders, "
            "waste analytics, notifications, access control, and Firebase Storage.",
            styles["CoverSub"],
        ),
        Spacer(1, 7 * mm),
        info_box(
            "Recommended foundation",
            "Cloud Firestore with each store as a tenant boundary, plus a reusable product catalog and separate inventory batches inside that store. "
            "Users may work in several stores with a different role in each one.",
            GREEN,
        ),
        Spacer(1, 9 * mm),
    ])
    cover_grid = Table([
        [Paragraph("<b>Platform</b><br/><font color='#6F776F'>Android + iOS only</font>", styles["Bodyx"]),
         Paragraph("<b>Tenancy</b><br/><font color='#6F776F'>Multiple isolated stores</font>", styles["Bodyx"]),
         Paragraph("<b>Status</b><br/><font color='#6F776F'>Awaiting approval</font>", styles["Bodyx"])],
    ], colWidths=[55.5 * mm] * 3)
    cover_grid.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, -1), BACKGROUND),
        ("BOX", (0, 0), (-1, -1), 0.7, BORDER),
        ("INNERGRID", (0, 0), (-1, -1), 0.7, BORDER),
        ("VALIGN", (0, 0), (-1, -1), "TOP"),
        ("LEFTPADDING", (0, 0), (-1, -1), 10),
        ("RIGHTPADDING", (0, 0), (-1, -1), 10),
        ("TOPPADDING", (0, 0), (-1, -1), 10),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 10),
    ]))
    story.extend([cover_grid, Spacer(1, 18 * mm), Paragraph("Prepared 09 September 2026", styles["Smallx"]), PageBreak()])

    story.extend(section_title("1", "What the app needs", "The schema is based on a screen-by-screen scan of the current Flutter project."))
    scan_rows = [
        ("Authentication and profile", "Firebase email/password sign-in, store selection, profile data, notification preferences, and logout."),
        ("Store administration", "Multiple isolated stores, store identity/address/settings, and per-store owner, manager, or staff membership."),
        ("Inventory administration", "Create/edit products, photo, category, barcode, quantity, expiry date, promotion price, and expiry alerts."),
        ("Stock operations", "Expiring-soon dashboard, inventory list, mark consumed, adjust stock, delete/close a batch."),
        ("Customer shopping", "Promotion catalog, search, batch expiry display, cart quantities, and checkout."),
        ("Orders", "To Pay, To Ship, To Receive, Completed; pickup/delivery; receiver snapshot; totals and payment state."),
        ("Waste reporting", "Waste by category and month, requiring a durable stock-event history rather than hard-coded chart totals."),
        ("Notifications", "Expiry warnings, consumed-stock activity, order updates, and optional Android/iOS push delivery."),
    ]
    table_data = [[Paragraph("Area", styles["Callout"]), Paragraph("Observed data requirement", styles["Callout"])]]
    for a, b in scan_rows:
        table_data.append([Paragraph(f"<b>{a}</b>", styles["Bodyx"]), Paragraph(b, styles["Bodyx"])])
    t = Table(table_data, colWidths=[48 * mm, 119 * mm], repeatRows=1)
    t.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, 0), GREEN_SOFT),
        ("BOX", (0, 0), (-1, -1), 0.7, BORDER),
        ("INNERGRID", (0, 0), (-1, -1), 0.45, BORDER),
        ("VALIGN", (0, 0), (-1, -1), "TOP"),
        ("LEFTPADDING", (0, 0), (-1, -1), 8),
        ("RIGHTPADDING", (0, 0), (-1, -1), 8),
        ("TOPPADDING", (0, 0), (-1, -1), 7),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 7),
    ]))
    story.extend([t, Spacer(1, 8 * mm)])
    story.append(info_box(
        "Important security finding",
        "The current prototype identifies the admin by the exact email admin@stockwise.com. "
        "Production authorization should instead check stores/{storeId}/members/{uid}.role. A platform-wide custom claim is reserved only for a trusted super administrator.",
        DANGER,
    ))
    story.append(Spacer(1, 5 * mm))
    story.append(info_box(
        "Category mismatch to resolve",
        "The item editor currently uses Dairy, Bakery, Produce, and Household, while waste reporting uses Dairy, Vegetables, Fruits, Meat, and Others. "
        "A categories collection creates one canonical list for both screens.",
        WARNING,
    ))
    story.append(PageBreak())

    story.extend(section_title("2", "Relationship map", "A store is the tenant boundary. Its catalog, inventory, carts, orders, reports, and alerts remain isolated from every other store."))
    story.append(relationship_diagram())
    story.append(Spacer(1, 5 * mm))
    story.append(info_box(
        "Why carts and orders point to batches",
        "A customer selects one store before shopping. Their cart, order, expiry date, promotional price, and stock reservation all remain inside that store.",
        PURPLE,
    ))
    story.append(PageBreak())

    story.extend(section_title("3", "Store tenancy and membership", "Store roles are not global. The same person can manage Store A, work as staff in Store B, and shop as a customer elsewhere."))
    story.append(collection_block("stores/{storeId}", "Tenant root and store identity", [
        "name: string", "code: string", "logoPath: string?", "ownerUid: uid",
        "phone: string?", "email: string?", "address: {line1, line2?, city, state, postalCode, countryCode}",
        "timezone: string", "currency: 'MYR'", "status: 'active' | 'suspended' | 'closed'",
        "createdAt: timestamp", "updatedAt: timestamp",
    ], PURPLE))
    story.append(collection_block("stores/{storeId}/members/{uid}", "Per-store privileged access", [
        "storeId: reference/id", "userId: uid", "role: 'owner' | 'manager' | 'staff'",
        "permissions: string[]?", "isActive: bool", "invitedBy: uid?",
        "joinedAt: timestamp", "updatedAt: timestamp",
    ], PURPLE))
    story.append(collection_block("users/{uid}", "Global account profile and preferences", [
        "email: string", "displayName: string", "phone: string?", "photoPath: string?",
        "activeStoreId: reference/id?", "preferences.expiryAlerts: bool",
        "preferences.orderUpdates: bool", "preferences.promotions: bool",
        "createdAt: timestamp", "updatedAt: timestamp",
    ]))
    story.append(info_box(
        "Tenant rule",
        "Every store-owned document stays below stores/{storeId}. Store staff access is authorized against that store's membership document. Customers do not need staff membership to shop or place their own orders.",
        PURPLE,
    ))
    story.append(PageBreak())

    story.extend(section_title("4", "Accounts and per-store catalog"))
    story.append(collection_block("users/{uid}/addresses/{addressId}", "Saved checkout destinations", [
        "label: string", "recipientName: string", "phone: string", "addressLine1: string",
        "addressLine2: string?", "city: string", "state: string", "postalCode: string",
        "countryCode: string", "isDefault: bool",
    ]))
    story.append(collection_block("stores/{storeId}/categories/{categoryId}", "Canonical categories for one store", [
        "storeId: reference/id",
        "name: string", "slug: string", "sortOrder: number", "isActive: bool",
        "createdAt: timestamp", "updatedAt: timestamp",
    ]))
    story.append(collection_block("stores/{storeId}/products/{productId}", "Reusable product master inside one store", [
        "storeId: reference/id",
        "name: string", "nameLowercase: string", "description: string?", "categoryId: reference/id",
        "barcode: string?", "imagePath: string?", "unitLabel: string", "basePriceCents: integer",
        "currency: 'MYR'", "isActive: bool", "createdBy: uid", "createdAt: timestamp", "updatedAt: timestamp",
    ]))
    story.append(info_box(
        "Money rule",
        "Store monetary values as integer cents. Example: RM 20.50 is stored as 2050. This avoids floating-point rounding errors.",
        BLUE,
    ))
    story.append(PageBreak())

    story.extend(section_title("5", "Per-store inventory and waste"))
    story.append(collection_block("stores/{storeId}/inventoryBatches/{batchId}", "A separately expiring delivery for one store", [
        "storeId: reference/id", "productId: reference/id", "productName: string (query/display copy)",
        "productNameLowercase: string", "categoryId: reference/id (query copy)",
        "imagePath: string? (display copy)", "unitLabel: string (display copy)",
        "expiryAt: timestamp", "quantityOnHand: integer", "quantityReserved: integer",
        "status: 'active' | 'depleted' | 'expired' | 'discarded'",
        "promotionEnabled: bool", "promotionPriceCents: integer?",
        "promotionStartsAt: timestamp?", "promotionEndsAt: timestamp?",
        "notifyOnExpiry: bool", "createdBy: uid", "createdAt: timestamp", "updatedAt: timestamp",
    ]))
    story.append(collection_block("stores/{storeId}/inventoryEvents/{eventId}", "Append-only store audit trail and waste source", [
        "storeId: reference/id", "batchId: reference/id", "productId: reference/id", "categoryId: reference/id",
        "eventType: 'received' | 'adjusted' | 'reserved' | 'released' | 'sold' | 'consumed' | 'discarded' | 'expired'",
        "quantity: integer", "quantityDelta: integer", "reason: string?", "actorUid: uid?",
        "orderId: reference/id?", "occurredAt: timestamp",
    ]))
    story.append(info_box(
        "Waste calculation",
        "Only discarded and expired events feed the waste dashboard. Sales and normal consumption reduce stock but are not counted as waste. Monthly totals and category composition are derived from this event history.",
        WARNING,
    ))
    story.append(Spacer(1, 5 * mm))
    story.append(info_box(
        "Atomic stock rule",
        "Cart reservation, order placement, release, and sale must update quantities in a Firestore transaction or trusted backend function so stock cannot become negative.",
        DANGER,
    ))
    story.append(PageBreak())

    story.extend(section_title("6", "Per-store cart and orders"))
    story.append(collection_block("stores/{storeId}/carts/{uid}", "One customer cart inside one store", [
        "storeId: reference/id", "ownerUid: uid", "updatedAt: timestamp",
    ], PURPLE))
    story.append(collection_block("stores/{storeId}/carts/{uid}/items/{batchId}", "Exact store batch selected by the customer", [
        "storeId: reference/id", "batchId: reference/id", "productId: reference/id", "productName: string", "imagePath: string?",
        "expiryAt: timestamp", "quantity: integer", "unitPriceCents: integer",
        "addedAt: timestamp", "updatedAt: timestamp",
    ], PURPLE))
    story.append(collection_block("stores/{storeId}/orders/{orderId}", "Store order header, receiver, payment, and totals", [
        "storeId: reference/id", "orderNumber: string (unique within store)", "userId: uid",
        "status: 'to_pay' | 'to_ship' | 'to_receive' | 'completed' | 'cancelled'",
        "paymentStatus: 'unpaid' | 'paid' | 'refunded'", "fulfillmentType: 'pickup' | 'delivery'",
        "receiver: {name, phone, email, addressLine1, addressLine2?, city, state, postalCode, countryCode}",
        "payment: {methodLabel, provider?, providerReference?}",
        "subtotalCents: integer", "shippingFeeCents: integer", "totalCents: integer", "currency: 'MYR'",
        "placedAt: timestamp", "updatedAt: timestamp", "completedAt: timestamp?",
    ], PURPLE))
    story.append(collection_block("stores/{storeId}/orders/{orderId}/items/{itemId}", "Immutable store receipt snapshot", [
        "storeId: reference/id", "productId: reference/id", "batchId: reference/id", "productName: string", "imagePath: string?",
        "expiryAt: timestamp", "unitLabel: string", "quantity: integer",
        "unitPriceCents: integer", "lineTotalCents: integer",
    ], PURPLE))
    story.append(info_box(
        "Payment boundary",
        "Store only payment state and provider-generated references. Never store bank credentials, passwords, card data, or e-wallet secrets in Firestore.",
        DANGER,
    ))
    story.append(PageBreak())

    story.extend(section_title("7", "Per-store notifications, settings, and files"))
    story.append(collection_block("stores/{storeId}/notifications/{notificationId}", "Store alert record for one recipient", [
        "storeId: reference/id", "recipientUid: uid", "type: 'expiry_warning' | 'stock_consumed' | 'order_status' | 'promotion'",
        "title: string", "body: string", "relatedCollection: string?", "relatedDocumentId: string?",
        "readAt: timestamp?", "createdAt: timestamp", "scheduledFor: timestamp?",
    ]))
    story.append(collection_block("users/{uid}/devices/{deviceId}", "Android/iOS push notification registration", [
        "fcmToken: string", "platform: 'android' | 'ios'", "enabled: bool", "lastSeenAt: timestamp",
    ]))
    story.append(collection_block("stores/{storeId}/settings/inventory", "Store-specific expiry behavior", [
        "expiryWarningDays: [2, 3, 7]",
    ]))
    story.append(collection_block("stores/{storeId}/settings/commerce", "Store-specific checkout configuration", [
        "currency: 'MYR'", "deliveryFeeCents: integer", "minimumOrderCents: integer?",
    ]))
    storage = Table([
        [Paragraph("Firebase Storage path", styles["Callout"]), Paragraph("Purpose", styles["Callout"])],
        [Paragraph("stores/{storeId}/product-images/{productId}/...", styles["Codex"]), Paragraph("Store catalog and promotion artwork", styles["Bodyx"])],
        [Paragraph("user-avatars/{uid}/...", styles["Codex"]), Paragraph("Profile photos", styles["Bodyx"])],
        [Paragraph("stores/{storeId}/order-attachments/{orderId}/...", styles["Codex"]), Paragraph("Optional store order documents", styles["Bodyx"])],
    ], colWidths=[78 * mm, 89 * mm])
    storage.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, 0), GREEN_SOFT),
        ("BOX", (0, 0), (-1, -1), 0.7, BORDER),
        ("INNERGRID", (0, 0), (-1, -1), 0.45, BORDER),
        ("VALIGN", (0, 0), (-1, -1), "TOP"),
        ("LEFTPADDING", (0, 0), (-1, -1), 8),
        ("RIGHTPADDING", (0, 0), (-1, -1), 8),
        ("TOPPADDING", (0, 0), (-1, -1), 7),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 7),
    ]))
    story.append(storage)
    story.append(PageBreak())

    story.extend(section_title("8", "Multi-store access control and indexes"))
    rules = [
        ("Users", "Read and update their own global profile, addresses, preferences, and devices."),
        ("Stores", "Active stores are discoverable; sensitive settings require active store membership."),
        ("Membership", "Owners manage managers/staff. Users may read their own membership. Store roles are never client-self-assigned."),
        ("Catalog", "Customers read active store products. Store owner, manager, or authorized staff create and update."),
        ("Inventory", "Authorized store members write. Customers read only sale-safe batches in the selected store."),
        ("Carts", "Owner-only read/write, constrained to the selected store."),
        ("Orders", "Customers create/read their own store orders. Authorized store members read that store's orders."),
        ("Notifications", "Recipients and authorized store staff read appropriate alerts. Trusted backend creates system alerts."),
        ("Devices", "Owner-only registration. Tokens are never publicly readable."),
    ]
    for title, body in rules:
        story.append(bullet(f"<b>{title}:</b> {body}"))
    story.append(Spacer(1, 4 * mm))
    story.append(info_box(
        "Role enforcement",
        "Authorize normal administration with stores/{storeId}/members/{uid}.role. Reserve a Firebase Authentication custom claim only for a rare platform-wide super administrator. This avoids granting one user admin rights over every store.",
        DANGER,
    ))
    story.append(Spacer(1, 6 * mm))
    story.append(Paragraph("Required composite indexes", styles["H2x"]))
    index_rows = [
        ("members (group)", "userId ASC, isActive ASC"),
        ("inventoryBatches", "status ASC, expiryAt ASC"),
        ("inventoryBatches", "promotionEnabled ASC, status ASC, expiryAt ASC"),
        ("orders", "userId ASC, status ASC, placedAt DESC"),
        ("orders", "status ASC, placedAt DESC"),
        ("notifications", "recipientUid ASC, createdAt DESC"),
        ("inventoryEvents", "eventType ASC, occurredAt DESC"),
        ("inventoryEvents", "categoryId ASC, eventType ASC, occurredAt DESC"),
    ]
    idx = Table(
        [[Paragraph("Collection", styles["Callout"]), Paragraph("Fields", styles["Callout"])]] +
        [[Paragraph(a, styles["Codex"]), Paragraph(b, styles["Codex"])] for a, b in index_rows],
        colWidths=[58 * mm, 109 * mm], repeatRows=1,
    )
    idx.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, 0), GREEN_SOFT),
        ("BOX", (0, 0), (-1, -1), 0.7, BORDER),
        ("INNERGRID", (0, 0), (-1, -1), 0.45, BORDER),
        ("LEFTPADDING", (0, 0), (-1, -1), 8),
        ("RIGHTPADDING", (0, 0), (-1, -1), 8),
        ("TOPPADDING", (0, 0), (-1, -1), 6),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 6),
    ]))
    story.append(idx)
    story.append(PageBreak())

    story.extend(section_title("9", "Approval checklist", "Approve the multi-store foundation before any Firestore collections, rules, indexes, Storage paths, or app repositories are wired."))
    choices = [
        ("Multi-store tenant isolation", "Each store owns its catalog, batches, carts, orders, reports, alerts, and settings."),
        ("Per-store staff roles", "A user can be owner, manager, or staff in different stores without receiving global admin access."),
        ("Product and batch separation", "Products are reusable masters; batches own expiry, available stock, and promotional price."),
        ("One cart per user per store", "Items from different stores are never mixed in one checkout."),
        ("Canonical categories", "Dairy, Bakery, Vegetables, Fruits, Meat, Household, and Others."),
        ("Membership-based security", "The admin email shortcut is replaced with store membership checks."),
        ("Event-derived waste analytics", "Only expired and discarded events count as waste."),
        ("Payment metadata only", "No sensitive financial credentials are stored."),
    ]
    check_rows = []
    for title, detail in choices:
        check_rows.append([
            Paragraph("[ ]", ParagraphStyle("box", parent=styles["Bodyx"], fontName="Helvetica-Bold", fontSize=10, leading=15, textColor=GREEN_DARK)),
            Paragraph(f"<b>{title}</b><br/><font color='#6F776F'>{detail}</font>", styles["Bodyx"]),
        ])
    checks = Table(check_rows, colWidths=[12 * mm, 155 * mm])
    checks.setStyle(TableStyle([
        ("BOX", (0, 0), (-1, -1), 0.7, BORDER),
        ("INNERGRID", (0, 0), (-1, -1), 0.45, BORDER),
        ("VALIGN", (0, 0), (-1, -1), "TOP"),
        ("LEFTPADDING", (0, 0), (-1, -1), 8),
        ("RIGHTPADDING", (0, 0), (-1, -1), 8),
        ("TOPPADDING", (0, 0), (-1, -1), 8),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 8),
    ]))
    story.extend([checks, Spacer(1, 8 * mm)])
    story.append(info_box(
        "Approval phrase",
        "Reply with: Approve Multi-store Schema v1. If you want changes, list them before approval and the schema can be revised without touching Firebase.",
        GREEN,
    ))
    story.append(Spacer(1, 10 * mm))
    story.append(Paragraph("Implementation after approval", styles["H2x"]))
    for text in [
        "Add Cloud Firestore, Firebase Storage, and optional Firebase Messaging dependencies.",
        "Create store selection, membership-aware navigation, typed models, repositories, and transactional stock operations.",
        "Deploy security rules and composite indexes.",
        "Replace hard-coded UI data with live streams and role-safe actions.",
        "Verify Android and iOS flows only.",
    ]:
        story.append(bullet(text))

    return story


def main():
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    doc = StockWiseDocTemplate(str(OUTPUT))
    doc.build(build_story())
    print(OUTPUT)


if __name__ == "__main__":
    main()
