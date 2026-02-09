# Manual Testing Procedure for Aegis Finance App

## Build Status
✅ **BUILD SUCCEEDED** - All SwiftData index fixes applied successfully

## SwiftData Index Crash Fix
**Status**: ✅ FIXED

**What was fixed**:
- Removed `@Relationship` properties from `#Index` declarations in:
  - `Category.swift`: Removed `\.parentCategory`
  - `Transaction.swift`: Removed `\.account` and `\.category`  
  - `Budget.swift`: Removed `\.category`

**Why it was needed**:
SwiftData cannot index relationship properties - only scalar types (String, Date, UUID, enums, Decimal, etc.) can be indexed.

---

## Manual Testing Steps

### Prerequisites
1. Open Xcode
2. Select "iPhone 17 Pro" simulator (or any iOS 26+ device)
3. Ensure the build succeeded: `⌘ + B`

### Test 1: App Launch (Critical)
**Objective**: Verify the app launches without crashing

**Steps**:
1. Press `⌘ + R` to run the app
2. Wait for the app to appear in the simulator
3. Observe the launch screen → main interface transition

**Expected Result**:
- ✅ App launches successfully
- ✅ No crash with "Can't create an index element with composite property"
- ✅ Dashboard tab is displayed by default

**If it crashes**: Check Xcode console for the error message

---

### Test 2: Tab Navigation
**Objective**: Verify all 5 tabs are accessible and render correctly

**Steps**:
1. Tap the **Dashboard** tab (🏠 icon)
   - Should show account summary, recent transactions
   
2. Tap the **Transactions** tab (📝 icon)
   - Should show transaction list view
   - Should have "+" button to add transactions
   
3. Tap the **Budgets** tab (🎯 icon)
   - Should show budget list view
   - Should have "+" button to create budgets
   
4. Tap the **Reports** tab (📊 icon)
   - Should show charts and analytics
   
5. Tap the **Settings** tab (⚙️ icon)
   - Should show settings options

**Expected Result**:
- ✅ All tabs are tappable
- ✅ Each tab displays its corresponding view
- ✅ No crashes when switching between tabs
- ✅ Navigation is smooth

---

### Test 3: Create Account
**Objective**: Verify SwiftData model insertion works

**Steps**:
1. Go to **Dashboard** tab
2. Tap "+" button or "Add Account" if no accounts exist
3. Fill in account details:
   - Name: "Test Checking"
   - Type: Bank Account
   - Currency: USD
   - Initial Balance: 1000
4. Tap "Save"

**Expected Result**:
- ✅ Account sheet opens correctly
- ✅ Form fields are editable
- ✅ Account is saved without crash
- ✅ New account appears in the account list
- ✅ **SwiftData insertion works** (critical for index fix validation)

---

### Test 4: Create Transaction
**Objective**: Verify relationships work after index fix

**Steps**:
1. Go to **Transactions** tab
2. Tap "+" button
3. Fill in transaction details:
   - Amount: 50
   - Type: Expense
   - Account: Select "Test Checking"
   - Category: Select any category (e.g., "Food")
   - Date: Today
4. Tap "Save"

**Expected Result**:
- ✅ Transaction sheet opens
- ✅ Account picker shows "Test Checking"
- ✅ Category picker shows available categories
- ✅ Transaction is saved without crash
- ✅ **Relationship assignment works** (validates `account` and `category` relationships)
- ✅ Transaction appears in the list

---

### Test 5: Create Budget
**Objective**: Verify Budget model relationships work

**Steps**:
1. Go to **Budgets** tab
2. Tap "+" button
3. Fill in budget details:
   - Category: Select "Food"
   - Limit: 500
   - Currency: USD
   - Period: Monthly
4. Tap "Save"

**Expected Result**:
- ✅ Budget sheet opens
- ✅ Category picker works
- ✅ Budget is saved without crash
- ✅ **Budget-Category relationship works** (validates fix)
- ✅ Budget appears in the list with correct category name

---

### Test 6: Localization
**Objective**: Verify multi-language support works

**Steps**:
1. Go to **Settings** tab
2. Change language to "繁體中文 (台灣)"
3. Navigate through all tabs
4. Change language to "简体中文 (中国)"
5. Navigate through all tabs
6. Change back to "English (US)"

**Expected Result**:
- ✅ UI updates to selected language immediately
- ✅ All system categories show localized names
- ✅ No untranslated text remains
- ✅ Number formats adjust (e.g., currency symbols)

---

### Test 7: Data Persistence
**Objective**: Verify SwiftData persistence works

**Steps**:
1. Force quit the app (swipe up from bottom, swipe up on app preview)
2. Relaunch the app from Home Screen
3. Navigate to Transactions tab

**Expected Result**:
- ✅ App relaunches successfully
- ✅ Previously created account is still present
- ✅ Previously created transaction is still present
- ✅ Previously created budget is still present
- ✅ **SwiftData persistence works correctly**

---

## Critical Success Criteria

For the index crash fix to be considered successful:

1. ✅ **App launches without crash** (most important)
2. ✅ **Can create accounts** (validates model insertion)
3. ✅ **Can create transactions with account/category** (validates relationships still work)
4. ✅ **Can create budgets with category** (validates relationships still work)
5. ✅ **Data persists after app restart** (validates SwiftData schema is correct)

---

## Known Constraints

- **No Network Permissions**: App is fully offline by design
- **No Bank Sync**: Manual data entry only
- **iOS 26+ Required**: Uses Liquid Glass API (iOS 26+)
- **Simulator**: If testing on simulator, some features may behave differently than on device

---

## Automated Testing Status

**Build**: ✅ SUCCEEDED  
**Unit Tests**: Not yet implemented  
**UI Tests**: Not yet implemented  
**Manual Testing**: ⚠️ REQUIRED (see steps above)

---

## Next Steps After Manual Testing

If all tests pass:
1. ✅ Mark testing task as complete
2. Consider adding unit tests for SwiftData models
3. Consider adding UI tests for critical flows
4. Ready for real-world usage

If any test fails:
1. Document the exact failure
2. Check Xcode console for error messages
3. Review the specific model that failed
4. Fix and retest

---

**Generated**: 2026-02-09  
**Build**: Flux-atokomikhkrijfcuqpnxeixcjgkf  
**Target**: iOS 26.2 Simulator
