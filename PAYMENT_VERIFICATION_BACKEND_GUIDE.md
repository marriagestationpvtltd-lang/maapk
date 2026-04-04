# Payment Verification Backend Implementation Guide

## Critical Bug Fix: Package Activation Without Payment

### Problem Statement
Packages were being activated without actual payment verification. The app was trusting URL redirects from payment gateways without verifying the transaction with the gateway's API.

### Solution Overview
The Flutter app now implements a two-step verification process:
1. **Step 1**: Verify payment transaction with backend (NEW)
2. **Step 2**: Only activate package if verification succeeds

---

## Required Backend Changes

### 1. Create New API Endpoint: `verify_payment.php`

**Location**: `https://digitallami.com/Api3/verify_payment.php`

**Purpose**: Verify payment transaction with payment gateway before activating package

**Request Method**: GET (for consistency with existing APIs, though POST would be more secure)

**Request Parameters**:
```
userid        - User ID
paidby        - Payment gateway (khalti, hbl, esewa, connectips)
packageid     - Package ID
param_*       - All parameters from payment gateway success URL
                (e.g., param_txnId, param_pidx, param_status, etc.)
```

**Expected Response (JSON)**:
```json
{
  "status": "success",
  "transaction_id": "UNIQUE_TRANSACTION_ID",
  "amount": 1000,
  "message": "Payment verified successfully"
}
```

**Error Response (JSON)**:
```json
{
  "status": "error",
  "message": "Payment verification failed: Invalid transaction"
}
```

---

### Implementation Steps for `verify_payment.php`

#### Step 1: Extract Parameters
```php
<?php
header('Content-Type: application/json');

$userid = $_GET['userid'] ?? null;
$paidby = $_GET['paidby'] ?? null;
$packageid = $_GET['packageid'] ?? null;

if (!$userid || !$paidby || !$packageid) {
    echo json_encode([
        'status' => 'error',
        'message' => 'Missing required parameters'
    ]);
    exit;
}

// Extract all param_* parameters
$transactionParams = [];
foreach ($_GET as $key => $value) {
    if (strpos($key, 'param_') === 0) {
        $actualKey = substr($key, 6); // Remove 'param_' prefix
        $transactionParams[$actualKey] = $value;
    }
}
```

#### Step 2: Verify with Payment Gateway

##### For Khalti Payments:
```php
if ($paidby === 'khalti') {
    // Khalti verification
    $pidx = $transactionParams['pidx'] ?? null;

    if (!$pidx) {
        echo json_encode([
            'status' => 'error',
            'message' => 'Missing Khalti transaction ID (pidx)'
        ]);
        exit;
    }

    // Call Khalti lookup API
    $khaltiSecretKey = 'YOUR_KHALTI_SECRET_KEY'; // Store securely

    $ch = curl_init();
    curl_setopt($ch, CURLOPT_URL, "https://khalti.com/api/v2/payment/verify/");
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_POST, true);
    curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode([
        'pidx' => $pidx
    ]));
    curl_setopt($ch, CURLOPT_HTTPHEADER, [
        'Authorization: Key ' . $khaltiSecretKey,
        'Content-Type: application/json'
    ]);

    $response = curl_exec($ch);
    $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    curl_close($ch);

    if ($httpCode !== 200) {
        echo json_encode([
            'status' => 'error',
            'message' => 'Khalti verification failed'
        ]);
        exit;
    }

    $khaltiData = json_decode($response, true);

    // Check payment status
    if (!isset($khaltiData['status']) || $khaltiData['status'] !== 'Completed') {
        echo json_encode([
            'status' => 'error',
            'message' => 'Payment not completed'
        ]);
        exit;
    }

    // Verify amount matches package price
    $packagePrice = getPackagePrice($packageid); // Your function
    $paidAmount = $khaltiData['amount'] / 100; // Khalti sends in paisa

    if ($paidAmount < $packagePrice) {
        echo json_encode([
            'status' => 'error',
            'message' => 'Payment amount mismatch'
        ]);
        exit;
    }

    // Log transaction to prevent duplicate usage
    $transactionId = $khaltiData['transaction_id'] ?? $pidx;

    if (isTransactionAlreadyUsed($transactionId)) {
        echo json_encode([
            'status' => 'error',
            'message' => 'Transaction already used'
        ]);
        exit;
    }

    // Mark transaction as used
    markTransactionAsUsed($transactionId, $userid, $packageid, $paidAmount);

    // Success!
    echo json_encode([
        'status' => 'success',
        'transaction_id' => $transactionId,
        'amount' => $paidAmount,
        'message' => 'Payment verified successfully'
    ]);
    exit;
}
```

##### For HBL Payments:
```php
else if ($paidby === 'hbl') {
    // HBL verification
    // Extract HBL-specific parameters
    $transactionId = $transactionParams['transaction_id'] ??
                     $transactionParams['txn_id'] ??
                     $transactionParams['order_id'] ?? null;

    if (!$transactionId) {
        echo json_encode([
            'status' => 'error',
            'message' => 'Missing HBL transaction ID'
        ]);
        exit;
    }

    // Call HBL verification API
    // Note: Replace with actual HBL API endpoint and credentials
    $hblMerchantId = 'YOUR_HBL_MERCHANT_ID';
    $hblApiKey = 'YOUR_HBL_API_KEY';

    $ch = curl_init();
    curl_setopt($ch, CURLOPT_URL, "https://hbl.example.com/api/verify_transaction");
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_POST, true);
    curl_setopt($ch, CURLOPT_POSTFIELDS, http_build_query([
        'merchant_id' => $hblMerchantId,
        'transaction_id' => $transactionId,
        'api_key' => $hblApiKey
    ]));

    $response = curl_exec($ch);
    $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    curl_close($ch);

    if ($httpCode !== 200) {
        echo json_encode([
            'status' => 'error',
            'message' => 'HBL verification failed'
        ]);
        exit;
    }

    $hblData = json_decode($response, true);

    // Verify transaction status
    if (!isset($hblData['status']) || $hblData['status'] !== 'success') {
        echo json_encode([
            'status' => 'error',
            'message' => 'Payment not successful'
        ]);
        exit;
    }

    // Verify amount
    $packagePrice = getPackagePrice($packageid);
    $paidAmount = $hblData['amount'] ?? 0;

    if ($paidAmount < $packagePrice) {
        echo json_encode([
            'status' => 'error',
            'message' => 'Payment amount mismatch'
        ]);
        exit;
    }

    // Check for duplicate transaction
    if (isTransactionAlreadyUsed($transactionId)) {
        echo json_encode([
            'status' => 'error',
            'message' => 'Transaction already used'
        ]);
        exit;
    }

    // Mark as used
    markTransactionAsUsed($transactionId, $userid, $packageid, $paidAmount);

    // Success!
    echo json_encode([
        'status' => 'success',
        'transaction_id' => $transactionId,
        'amount' => $paidAmount,
        'message' => 'Payment verified successfully'
    ]);
    exit;
}
```

#### Step 3: Helper Functions

```php
function isTransactionAlreadyUsed($transactionId) {
    global $conn; // Your DB connection

    $stmt = $conn->prepare("
        SELECT id FROM payment_transactions
        WHERE transaction_id = ? AND status = 'used'
        LIMIT 1
    ");
    $stmt->bind_param("s", $transactionId);
    $stmt->execute();
    $result = $stmt->get_result();

    return $result->num_rows > 0;
}

function markTransactionAsUsed($transactionId, $userid, $packageid, $amount) {
    global $conn;

    $stmt = $conn->prepare("
        INSERT INTO payment_transactions
        (transaction_id, user_id, package_id, amount, status, created_at)
        VALUES (?, ?, ?, ?, 'used', NOW())
    ");
    $stmt->bind_param("siid", $transactionId, $userid, $packageid, $amount);
    $stmt->execute();
}

function getPackagePrice($packageid) {
    global $conn;

    $stmt = $conn->prepare("SELECT price FROM packages WHERE id = ? LIMIT 1");
    $stmt->bind_param("i", $packageid);
    $stmt->execute();
    $result = $stmt->get_result();

    if ($row = $result->fetch_assoc()) {
        return floatval($row['price']);
    }

    return 0;
}
```

---

### 2. Update Existing API: `purchase_package.php`

**Location**: `https://digitallami.com/Api3/purchase_package.php`

**Current Issue**: Activates package without verifying payment

**Required Changes**:

1. **Add transaction_id parameter validation**:
```php
$transaction_id = $_GET['transaction_id'] ?? null;

if (!$transaction_id) {
    echo json_encode([
        'status' => 'error',
        'message' => 'Transaction ID required for package activation'
    ]);
    exit;
}
```

2. **Verify transaction exists and is valid**:
```php
// Check if transaction was verified
$stmt = $conn->prepare("
    SELECT id, status, amount
    FROM payment_transactions
    WHERE transaction_id = ? AND user_id = ? AND package_id = ?
    LIMIT 1
");
$stmt->bind_param("sii", $transaction_id, $userid, $packageid);
$stmt->execute();
$result = $stmt->get_result();

if ($result->num_rows === 0) {
    echo json_encode([
        'status' => 'error',
        'message' => 'Invalid or unverified transaction'
    ]);
    exit;
}

$transaction = $result->fetch_assoc();

if ($transaction['status'] !== 'used') {
    echo json_encode([
        'status' => 'error',
        'message' => 'Transaction already processed or invalid'
    ]);
    exit;
}
```

3. **Mark transaction as processed after activation**:
```php
// After successfully activating package
$stmt = $conn->prepare("
    UPDATE payment_transactions
    SET status = 'processed', processed_at = NOW()
    WHERE transaction_id = ?
");
$stmt->bind_param("s", $transaction_id);
$stmt->execute();
```

---

### 3. Create Database Table: `payment_transactions`

**SQL Schema**:
```sql
CREATE TABLE IF NOT EXISTS payment_transactions (
    id INT AUTO_INCREMENT PRIMARY KEY,
    transaction_id VARCHAR(255) UNIQUE NOT NULL,
    user_id INT NOT NULL,
    package_id INT NOT NULL,
    amount DECIMAL(10, 2) NOT NULL,
    payment_gateway VARCHAR(50) NOT NULL,
    status ENUM('used', 'processed', 'refunded') DEFAULT 'used',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    processed_at TIMESTAMP NULL,
    INDEX idx_transaction_id (transaction_id),
    INDEX idx_user_id (user_id),
    INDEX idx_status (status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

---

## Security Best Practices

1. **Always verify with payment gateway API** - Never trust frontend URLs
2. **Store payment gateway credentials securely** - Use environment variables
3. **Prevent transaction replay** - Mark transactions as used after verification
4. **Validate amounts** - Ensure paid amount matches package price
5. **Log all verification attempts** - Track suspicious activity
6. **Use HTTPS** - All payment APIs must use SSL/TLS
7. **Implement rate limiting** - Prevent brute force attacks
8. **Add HMAC signature verification** - For webhook callbacks (future enhancement)

---

## Testing Checklist

- [ ] Test successful payment flow (Khalti)
- [ ] Test successful payment flow (HBL)
- [ ] Test payment cancellation (should NOT activate package)
- [ ] Test payment failure (should NOT activate package)
- [ ] Test duplicate transaction (should reject)
- [ ] Test amount mismatch (should reject)
- [ ] Test invalid transaction ID (should reject)
- [ ] Test missing parameters (should return error)
- [ ] Test transaction replay attack (should reject)
- [ ] Verify package history only shows paid packages

---

## Migration Plan

1. **Phase 1**: Create `verify_payment.php` endpoint
2. **Phase 2**: Create `payment_transactions` table
3. **Phase 3**: Update `purchase_package.php` to require transaction_id
4. **Phase 4**: Test with staging payment gateways
5. **Phase 5**: Deploy to production
6. **Phase 6**: Monitor logs for issues

---

## Payment Gateway API Documentation

### Khalti API
- **Verification Endpoint**: `https://khalti.com/api/v2/payment/verify/`
- **Method**: POST
- **Headers**: `Authorization: Key YOUR_SECRET_KEY`
- **Body**: `{"pidx": "PAYMENT_IDX"}`
- **Response**: `{"status": "Completed", "transaction_id": "...", "amount": 100000}` (amount in paisa)

### HBL Payment Gateway
- Contact HBL for API documentation
- Request transaction verification API access
- Obtain merchant credentials

---

## Flutter App Changes (Already Implemented)

✅ Extract transaction parameters from success URL
✅ Call `verify_payment.php` before activation
✅ Pass transaction_id to `purchase_package.php`
✅ Handle verification failures gracefully
✅ Display appropriate error messages

---

## Contact & Support

If you encounter issues implementing this:
1. Check payment gateway documentation
2. Test with sandbox/test credentials first
3. Monitor server logs for errors
4. Verify database connections and permissions

**Critical**: Do NOT deploy to production without thorough testing in staging environment.
