// Copyright The Libphonenumber Authors. Apache-2.0.
// MY metadata source/retrieval date and license are in data/malaysia_phone_patterns.json
// and data/libphonenumber_LICENSE.txt. No SMS or ownership verification is used.
const {patterns} = require('./data/malaysia_phone_patterns.json');
const malaysianNationalNumberPattern = Object.values(patterns).join('|');
const nationalPattern = new RegExp(`^(?:${malaysianNationalNumberPattern})$`);
const servicePattern = new RegExp(`^(?:${patterns.tollFree}|${patterns.premiumRate})$`);
const allowedCharacters = /^[+0-9 ()-]+$/;
const balancedParentheses = /^[^()]*(?:\([^()]*[0-9][^()]*\)[^()]*)*$/;

function normalizeMalaysianPhone(value) {
  if (typeof value !== 'string') return null;
  const raw = value.trim();
  if (!raw || raw.length > 64 || !allowedCharacters.test(raw) || !balancedParentheses.test(raw)) return null;
  const compact = raw.replace(/[ ()-]/g, '');
  if (!/^\+?[0-9]+$/.test(compact)) return null;
  let national;
  if (compact.startsWith('+60')) national = compact.slice(3);
  else if (compact.startsWith('0060')) national = compact.slice(4);
  else if (compact.startsWith('60')) national = compact.slice(2);
  else if (compact.startsWith('0')) national = compact.slice(1);
  else if (servicePattern.test(compact)) national = compact;
  else return null;
  return nationalPattern.test(national) ? `+60${national}` : null;
}

function isValidMalaysianPhone(value) {
  return normalizeMalaysianPhone(value) !== null;
}

module.exports = {normalizeMalaysianPhone, isValidMalaysianPhone, malaysianNationalNumberPattern, patterns};
