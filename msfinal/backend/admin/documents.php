<?php
$title = 'Document Verification';
require_once 'includes/header.php';

// Get documents from API
function getDocuments() {
    $url = 'https://digitallami.com/api9/get_documents.php';
    
    $ch = curl_init();
    curl_setopt($ch, CURLOPT_URL, $url);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_HTTPHEADER, [
        'Accept: application/json'
    ]);
    
    $response = curl_exec($ch);
    $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    curl_close($ch);
    
    if ($httpCode === 200) {
        $data = json_decode($response, true);
        if ($data['success']) {
            return $data['data'];
        }
    }
    
    return [];
}

// Handle approve/reject actions
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $action = $_POST['action'] ?? '';
    $userId = $_POST['user_id'] ?? '';
    $rejectReason = $_POST['reject_reason'] ?? '';
    
    if ($action && $userId) {
        $url = 'https://digitallami.com/api9/update_document_status.php';
        
        $postData = [
            'user_id' => $userId,
            'action' => $action
        ];
        
        if ($action === 'reject' && $rejectReason) {
            $postData['reject_reason'] = $rejectReason;
        }
        
        $ch = curl_init();
        curl_setopt($ch, CURLOPT_URL, $url);
        curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
        curl_setopt($ch, CURLOPT_POST, true);
        curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($postData));
        curl_setopt($ch, CURLOPT_HTTPHEADER, [
            'Content-Type: application/json',
            'Accept: application/json'
        ]);
        
        $response = curl_exec($ch);
        $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
        curl_close($ch);
        
        if ($httpCode === 200) {
            $result = json_decode($response, true);
            if ($result['success']) {
                echo '<script>Swal.fire("Success", ' . json_encode($result['message'] ?? '', JSON_HEX_TAG | JSON_HEX_AMP | JSON_HEX_APOS | JSON_HEX_QUOT) . ', "success");</script>';
            } else {
                echo '<script>Swal.fire("Error", ' . json_encode($result['message'] ?? 'Action failed', JSON_HEX_TAG | JSON_HEX_AMP | JSON_HEX_APOS | JSON_HEX_QUOT) . ', "error");</script>';
            }
        } else {
            echo '<script>Swal.fire("Error", "Server error", "error");</script>';
        }
    }
}

$documents = getDocuments();

// Filter documents by status
$pendingDocs = array_filter($documents, fn($doc) => $doc['status'] === 'pending');
$approvedDocs = array_filter($documents, fn($doc) => $doc['status'] === 'approved');
$rejectedDocs = array_filter($documents, fn($doc) => $doc['status'] === 'rejected');
?>

<div class="row mb-4">
    <div class="col-12">
        <div class="d-flex justify-content-between align-items-center">
            <h4 class="fw-bold">Document Verification</h4>
            <div>
                <button class="btn btn-primary" onclick="location.reload()">
                    <i class="fas fa-sync-alt me-2"></i> Refresh
                </button>
            </div>
        </div>
    </div>
</div>

<div class="row mb-4">
    <div class="col-12">
        <ul class="nav nav-tabs" id="docTabs" role="tablist">
            <li class="nav-item" role="presentation">
                <button class="nav-link active" id="pending-tab" data-bs-toggle="tab" data-bs-target="#pending" type="button" role="tab">
                    Pending <span class="badge bg-warning ms-2"><?php echo count($pendingDocs); ?></span>
                </button>
            </li>
            <li class="nav-item" role="presentation">
                <button class="nav-link" id="approved-tab" data-bs-toggle="tab" data-bs-target="#approved" type="button" role="tab">
                    Approved <span class="badge bg-success ms-2"><?php echo count($approvedDocs); ?></span>
                </button>
            </li>
            <li class="nav-item" role="presentation">
                <button class="nav-link" id="rejected-tab" data-bs-toggle="tab" data-bs-target="#rejected" type="button" role="tab">
                    Rejected <span class="badge bg-danger ms-2"><?php echo count($rejectedDocs); ?></span>
                </button>
            </li>
        </ul>
        
        <div class="tab-content mt-4" id="docTabsContent">
            <!-- Pending Tab -->
            <div class="tab-pane fade show active" id="pending" role="tabpanel">
                <?php if (empty($pendingDocs)): ?>
                    <div class="text-center py-5">
                        <i class="fas fa-file-alt fa-3x text-muted mb-3"></i>
                        <h5 class="text-muted">No pending documents to review</h5>
                    </div>
                <?php else: ?>
                    <div class="row">
                        <?php foreach ($pendingDocs as $doc): ?>
                            <div class="col-md-6 mb-4">
                                <div class="card">
                                    <div class="card-body">
                                        <!-- Document Image -->
                                        <div class="document-image mb-3">
                                            <?php if (!empty($doc['photo'])): ?>
                                                <img src="https://digitallami.com/<?php echo htmlspecialchars($doc['photo']); ?>" 
                                                     alt="Document" class="img-fluid" 
                                                     style="max-height: 200px; object-fit: contain;">
                                            <?php else: ?>
                                                <i class="fas fa-file-image fa-3x"></i>
                                            <?php endif; ?>
                                        </div>
                                        
                                        <!-- User Info -->
                                        <div class="mb-3">
                                            <h5 class="fw-bold"><?php echo htmlspecialchars($doc['firstName'] . ' ' . $doc['lastName']); ?></h5>
                                            <p class="text-muted mb-2">
                                                <i class="fas fa-envelope me-2"></i>
                                                <?php echo htmlspecialchars($doc['email']); ?>
                                            </p>
                                            <p class="text-muted mb-2">
                                                <i class="fas fa-id-card me-2"></i>
                                                <?php echo htmlspecialchars($doc['documenttype']); ?>
                                            </p>
                                            <p class="text-muted mb-0">
                                                <i class="fas fa-hashtag me-2"></i>
                                                ID: <?php echo htmlspecialchars($doc['documentidnumber']); ?>
                                            </p>
                                        </div>
                                        
                                        <!-- Action Buttons -->
                                        <div class="action-buttons d-flex gap-2">
                                            <button class="btn btn-success flex-fill" 
                                                    onclick="approveDocument(<?php echo intval($doc['user_id']); ?>)">
                                                <i class="fas fa-check me-2"></i> Approve
                                            </button>
                                            <button class="btn btn-danger flex-fill" 
                                                    onclick="rejectDocument(<?php echo intval($doc['user_id']); ?>, '<?php echo htmlspecialchars($doc['firstName'] . ' ' . $doc['lastName']); ?>')">
                                                <i class="fas fa-times me-2"></i> Reject
                                            </button>
                                        </div>
                                    </div>
                                </div>
                            </div>
                        <?php endforeach; ?>
                    </div>
                <?php endif; ?>
            </div>
            
            <!-- Approved Tab -->
            <div class="tab-pane fade" id="approved" role="tabpanel">
                <?php if (empty($approvedDocs)): ?>
                    <div class="text-center py-5">
                        <i class="fas fa-check-circle fa-3x text-muted mb-3"></i>
                        <h5 class="text-muted">No approved documents yet</h5>
                    </div>
                <?php else: ?>
                    <div class="table-responsive">
                        <table class="table table-hover">
                            <thead>
                                <tr>
                                    <th>User</th>
                                    <th>Document Type</th>
                                    <th>ID Number</th>
                                    <th>Status</th>
                                    <th>Date</th>
                                </tr>
                            </thead>
                            <tbody>
                                <?php foreach ($approvedDocs as $doc): ?>
                                    <tr>
                                        <td>
                                            <div class="d-flex align-items-center">
                                                <div class="avatar me-3">
                                                    <div style="width: 36px; height: 36px; background: #d1fae5; border-radius: 50%; display: flex; align-items: center; justify-content: center; color: #059669;">
                                                        <i class="fas fa-user"></i>
                                                    </div>
                                                </div>
                                                <div>
                                                    <h6 class="mb-0"><?php echo htmlspecialchars($doc['firstName'] . ' ' . $doc['lastName']); ?></h6>
                                                    <small class="text-muted"><?php echo htmlspecialchars($doc['email']); ?></small>
                                                </div>
                                            </div>
                                        </td>
                                        <td><?php echo htmlspecialchars($doc['documenttype']); ?></td>
                                        <td><?php echo htmlspecialchars($doc['documentidnumber']); ?></td>
                                        <td><span class="badge badge-approved">Approved</span></td>
                                        <td>
                                            <?php 
                                                // You can add date field to your API or use current date
                                                echo date('Y-m-d H:i');
                                            ?>
                                        </td>
                                    </tr>
                                <?php endforeach; ?>
                            </tbody>
                        </table>
                    </div>
                <?php endif; ?>
            </div>
            
            <!-- Rejected Tab -->
            <div class="tab-pane fade" id="rejected" role="tabpanel">
                <?php if (empty($rejectedDocs)): ?>
                    <div class="text-center py-5">
                        <i class="fas fa-times-circle fa-3x text-muted mb-3"></i>
                        <h5 class="text-muted">No rejected documents</h5>
                    </div>
                <?php else: ?>
                    <div class="table-responsive">
                        <table class="table table-hover">
                            <thead>
                                <tr>
                                    <th>User</th>
                                    <th>Document Type</th>
                                    <th>ID Number</th>
                                    <th>Status</th>
                                    <th>Reason</th>
                                </tr>
                            </thead>
                            <tbody>
                                <?php foreach ($rejectedDocs as $doc): ?>
                                    <tr>
                                        <td>
                                            <div class="d-flex align-items-center">
                                                <div class="avatar me-3">
                                                    <div style="width: 36px; height: 36px; background: #fee2e2; border-radius: 50%; display: flex; align-items: center; justify-content: center; color: #dc2626;">
                                                        <i class="fas fa-user"></i>
                                                    </div>
                                                </div>
                                                <div>
                                                    <h6 class="mb-0"><?php echo htmlspecialchars($doc['firstName'] . ' ' . $doc['lastName']); ?></h6>
                                                    <small class="text-muted"><?php echo htmlspecialchars($doc['email']); ?></small>
                                                </div>
                                            </div>
                                        </td>
                                        <td><?php echo htmlspecialchars($doc['documenttype']); ?></td>
                                        <td><?php echo htmlspecialchars($doc['documentidnumber']); ?></td>
                                        <td><span class="badge badge-rejected">Rejected</span></td>
                                        <td>
                                            <span class="text-muted">
                                                <!-- Add reject_reason field to your API response -->
                                                Document verification failed
                                            </span>
                                        </td>
                                    </tr>
                                <?php endforeach; ?>
                            </tbody>
                        </table>
                    </div>
                <?php endif; ?>
            </div>
        </div>
    </div>
</div>

<!-- Reject Reason Modal -->
<div class="modal fade" id="rejectModal" tabindex="-1" aria-hidden="true">
    <div class="modal-dialog">
        <div class="modal-content">
            <div class="modal-header">
                <h5 class="modal-title">Reject Document</h5>
                <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
            </div>
            <form method="POST" id="rejectForm">
                <div class="modal-body">
                    <input type="hidden" name="action" value="reject">
                    <input type="hidden" name="user_id" id="rejectUserId">
                    <div class="mb-3">
                        <label for="rejectReason" class="form-label">Rejection Reason</label>
                        <textarea class="form-control" id="rejectReason" name="reject_reason" rows="3" 
                                  placeholder="Enter reason for rejection..." required></textarea>
                    </div>
                </div>
                <div class="modal-footer">
                    <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">Cancel</button>
                    <button type="submit" class="btn btn-danger">Reject Document</button>
                </div>
            </form>
        </div>
    </div>
</div>

<!-- Approve Form -->
<form method="POST" id="approveForm" style="display: none;">
    <input type="hidden" name="action" value="approve">
    <input type="hidden" name="user_id" id="approveUserId">
</form>

<!-- JavaScript Libraries -->
<script src="https://code.jquery.com/jquery-3.6.4.min.js"></script>
<script src="https://cdn.datatables.net/1.13.4/js/jquery.dataTables.min.js"></script>
<script src="https://cdn.datatables.net/1.13.4/js/dataTables.bootstrap5.min.js"></script>
<script src="https://cdn.jsdelivr.net/npm/sweetalert2@11"></script>

<script>
// Initialize DataTables
$(document).ready(function() {
    $('table').DataTable({
        pageLength: 10,
        responsive: true
    });
});

// Approve document function
function approveDocument(userId) {
    Swal.fire({
        title: 'Are you sure?',
        text: 'This document will be approved',
        icon: 'warning',
        showCancelButton: true,
        confirmButtonColor: '#10b981',
        cancelButtonColor: '#6b7280',
        confirmButtonText: 'Yes, approve it!'
    }).then((result) => {
        if (result.isConfirmed) {
            $('#approveUserId').val(userId);
            $('#approveForm').submit();
        }
    });
}

// Reject document function
let currentUserId = null;
let currentUserName = null;

function rejectDocument(userId, userName) {
    currentUserId = userId;
    currentUserName = userName;
    
    $('#rejectUserId').val(userId);
    $('#rejectReason').val('');
    
    // Update modal title with user name
    $('#rejectModal .modal-title').html(`Reject Document - ${userName}`);
    
    // Show modal
    const modal = new bootstrap.Modal(document.getElementById('rejectModal'));
    modal.show();
}

// Handle reject form submission
$('#rejectForm').on('submit', function(e) {
    e.preventDefault();
    
    if ($('#rejectReason').val().trim() === '') {
        Swal.fire('Error', 'Please enter rejection reason', 'error');
        return;
    }
    
    Swal.fire({
        title: 'Are you sure?',
        text: 'This document will be rejected',
        icon: 'warning',
        showCancelButton: true,
        confirmButtonColor: '#ef4444',
        cancelButtonColor: '#6b7280',
        confirmButtonText: 'Yes, reject it!'
    }).then((result) => {
        if (result.isConfirmed) {
            this.submit();
        }
    });
});

// Auto-refresh every 30 seconds
setInterval(() => {
    // You can add auto-refresh logic here
}, 30000);
</script>

<?php require_once 'includes/footer.php'; ?>