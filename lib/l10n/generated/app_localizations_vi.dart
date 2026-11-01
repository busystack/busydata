// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Vietnamese (`vi`).
class AppLocalizationsVi extends AppLocalizations {
  AppLocalizationsVi([String locale = 'vi']) : super(locale);

  @override
  String get cancel => 'Hủy';

  @override
  String get windowMinimize => 'Thu nhỏ';

  @override
  String get windowMaximize => 'Phóng to';

  @override
  String get windowRestore => 'Khôi phục';

  @override
  String get databaseExplorer => 'Trình duyệt cơ sở dữ liệu';

  @override
  String get databases => 'Cơ sở dữ liệu';

  @override
  String get newConnection => 'Kết nối mới';

  @override
  String get filterTree => 'Lọc kết nối và đối tượng';

  @override
  String get treeFilterScope => 'Lọc các đối tượng cây đã tải';

  @override
  String get searchObjects => 'Tìm đối tượng cơ sở dữ liệu';

  @override
  String get fileMenu => 'Tệp';

  @override
  String get editMenu => 'Chỉnh sửa';

  @override
  String get viewMenu => 'Hiển thị';

  @override
  String get connectionMenu => 'Kết nối';

  @override
  String get objectMenu => 'Đối tượng';

  @override
  String get runMenu => 'Tùy chọn chạy';

  @override
  String get commands => 'Lệnh';

  @override
  String get findCommand => 'Tìm lệnh';

  @override
  String get newSql => 'Truy vấn mới';

  @override
  String get openSql => 'Mở SQL';

  @override
  String get openSqlFile => 'Mở tệp SQL';

  @override
  String get saveSql => 'Lưu SQL';

  @override
  String get closeTab => 'Đóng thẻ';

  @override
  String get openWorkspace => 'Mở không gian làm việc';

  @override
  String get saveWorkspace => 'Lưu không gian làm việc';

  @override
  String get settings => 'Cài đặt';

  @override
  String get findText => 'Tìm';

  @override
  String get replaceText => 'Thay thế';

  @override
  String get formatSql => 'Định dạng SQL';

  @override
  String get lineComments => 'Bật/tắt chú thích dòng';

  @override
  String get snippets => 'Đoạn mã SQL';

  @override
  String get run => 'Chạy';

  @override
  String get runStatement => 'Chạy câu lệnh hiện tại';

  @override
  String get runSelection => 'Chạy phần chọn';

  @override
  String get runScript => 'Chạy tập lệnh';

  @override
  String get explain => 'Giải thích kế hoạch';

  @override
  String get explainAnalyze => 'Giải thích và phân tích';

  @override
  String get connect => 'Kết nối';

  @override
  String get disconnect => 'Ngắt kết nối';

  @override
  String get sessionDetails => 'Chi tiết phiên';

  @override
  String get beginTransaction => 'Bắt đầu giao dịch';

  @override
  String get commitTransaction => 'Xác nhận giao dịch';

  @override
  String get rollbackTransaction => 'Hoàn tác giao dịch';

  @override
  String get enableAutoCommit => 'Bật tự động xác nhận';

  @override
  String get disableAutoCommit => 'Tắt tự động xác nhận';

  @override
  String get outcomeUnknown => 'Chưa rõ kết quả';

  @override
  String get outcomeUnknownNote =>
      'Thao tác có thể đã hoàn tất. Phiên này không thể chạy thêm SQL. Không bao giờ tự động thử lại; xác minh kết quả trước khi bắt đầu công việc mới.';

  @override
  String get notConnected => 'Đã ngắt kết nối';

  @override
  String get autoCommit => 'Tự động xác nhận';

  @override
  String get manualTransaction => 'Giao dịch thủ công';

  @override
  String get readOnlyPolicy => 'Chính sách chỉ đọc của BusyData';

  @override
  String get data => 'Dữ liệu';

  @override
  String get structure => 'Cấu trúc';

  @override
  String get results => 'Kết quả';

  @override
  String get messages => 'Thông báo';

  @override
  String get plan => 'Kế hoạch';

  @override
  String get changes => 'Thay đổi';

  @override
  String get history => 'Lịch sử';

  @override
  String get jobs => 'Tác vụ';

  @override
  String get retainedResults => 'Kết quả lưu giữ';

  @override
  String get recoverEdits => 'Khôi phục thay đổi đã chuẩn bị';

  @override
  String get applyAndCommit => 'Áp dụng và xác nhận';

  @override
  String get inspectStructure => 'Kiểm tra cấu trúc';

  @override
  String get openData => 'Mở dữ liệu';

  @override
  String get openDefinition => 'Mở định nghĩa';

  @override
  String get copyQualifiedName => 'Sao chép tên đầy đủ';

  @override
  String get refresh => 'Làm mới';

  @override
  String get columns => 'Cột';

  @override
  String get indexes => 'Chỉ mục';

  @override
  String get constraints => 'Khóa và ràng buộc';

  @override
  String get foreignKeys => 'Khóa ngoại';

  @override
  String get triggers => 'Trigger';

  @override
  String get definition => 'Định nghĩa';

  @override
  String get dependencies => 'Phụ thuộc';

  @override
  String get connectionCapabilities => 'Tổng quan kết nối';

  @override
  String get sessionsAndLocks => 'Phiên và khóa';

  @override
  String get usersAndRoles => 'Người dùng và vai trò';

  @override
  String get saveSnapshot => 'Lưu ảnh chụp lược đồ';

  @override
  String get compareSchemas => 'So sánh lược đồ';

  @override
  String get objectDesigner => 'Thiết kế đối tượng';

  @override
  String get diagram => 'Sơ đồ ER';

  @override
  String get backup => 'Sao lưu';

  @override
  String get restore => 'Khôi phục';

  @override
  String get importData => 'Nhập dữ liệu';

  @override
  String get exportRetained => 'Xuất dữ liệu lưu giữ';

  @override
  String get exportSql => 'Chạy SQL để xuất';

  @override
  String get stageInsert => 'Chèn hàng';

  @override
  String get stageUpdate => 'Sửa hàng';

  @override
  String get stageDelete => 'Xóa hàng';

  @override
  String get discardChanges => 'Bỏ thay đổi đang chờ';

  @override
  String get disposeResult => 'Giải phóng dữ liệu lưu giữ';

  @override
  String get currentSchema => 'Lược đồ hiện tại (sẽ thay đổi)';

  @override
  String get desiredSchema => 'Lược đồ mong muốn';

  @override
  String get applyTo => 'Áp dụng vào';

  @override
  String get loading => 'Đang tải';

  @override
  String get empty => 'Không có đối tượng trong phạm vi này';

  @override
  String get more => 'Thêm';

  @override
  String get filter => 'Lọc';

  @override
  String get sort => 'Sắp xếp';

  @override
  String get selectTarget => 'Chọn kết nối';

  @override
  String get requireSql => 'Cần tài liệu SQL';

  @override
  String get requireSession => 'Cần phiên đã kết nối và có trạng thái xác định';

  @override
  String get requireResult => 'Cần dữ liệu lưu giữ';

  @override
  String get requireObject => 'Cần đối tượng đích';

  @override
  String get cancelRequested => 'Đã yêu cầu hủy';

  @override
  String get cancelled => 'Đã hủy';

  @override
  String get queued => 'Đang chờ';

  @override
  String get running => 'Đang chạy';

  @override
  String get completed => 'Hoàn thành';

  @override
  String get failed => 'Thất bại';

  @override
  String get partial => 'Một phần';

  @override
  String get sessionSharing => 'Chia sẻ phiên hiện có (nâng cao)';

  @override
  String get production => 'Sản xuất';

  @override
  String get staging => 'Tiền sản xuất';

  @override
  String get development => 'Phát triển';

  @override
  String get executionOptions => 'Thiết lập thực thi';

  @override
  String get resultRowLimit => 'Giới hạn hàng kết quả (1–1000000)';

  @override
  String get boundedRead => 'Đọc có giới hạn';

  @override
  String get streamingRead => 'Đọc luồng · sở hữu giao dịch đọc';

  @override
  String get stopOnError => 'Dừng tập lệnh khi có lỗi';

  @override
  String get continueOnError =>
      'Tiếp tục khi có lỗi · câu lệnh trước có thể đã được xác nhận';

  @override
  String get loadMore => 'Tải thêm';

  @override
  String get favorite => 'Bật/tắt yêu thích';

  @override
  String get connectionGroup => 'Nhóm kết nối';

  @override
  String get copyRange => 'Sao chép vùng';

  @override
  String get inspectValue => 'Kiểm tra giá trị';

  @override
  String get editConnection => 'Sửa kết nối';

  @override
  String get chooseSnapshot => 'Chọn ảnh chụp';

  @override
  String get captureSchema => 'Chụp lược đồ';

  @override
  String get sameSchemaRestriction =>
      'Ảnh chụp phải có cùng loại máy cơ sở dữ liệu, tên lược đồ và phiên bản ảnh chụp. So sánh và lưu không bao giờ áp dụng thay đổi.';

  @override
  String get restoredTaskState =>
      'Tham chiếu tài liệu này đã được khôi phục. Bằng chứng máy chủ, phiên và tác vụ trước đây không còn khả dụng. Chọn thao tác rõ ràng để kiểm tra hoặc bắt đầu công việc mới; khôi phục không bao giờ kết nối, chạy SQL hoặc phát lại thay đổi.';

  @override
  String get preChangeSnapshot =>
      'Ảnh chụp trước thay đổi · thay đổi đã xác nhận. Làm mới rõ ràng để xem hàng hiện tại và giá trị mặc định của máy chủ.';

  @override
  String get sqlProvenance => 'Nguồn gốc SQL';

  @override
  String get assessEditing => 'Đánh giá khả năng sửa';

  @override
  String get viewDetails => 'Xem chi tiết';

  @override
  String get gridMenu => 'Lưới dữ liệu';

  @override
  String get visibleColumns => 'Cột hiển thị';

  @override
  String get hidden => 'Ẩn';

  @override
  String get ascending => 'Tăng dần';

  @override
  String get descending => 'Giảm dần';

  @override
  String get equals => 'Bằng';

  @override
  String get notEqual => 'Không bằng';

  @override
  String get lessThan => 'Nhỏ hơn';

  @override
  String get greaterThan => 'Lớn hơn';

  @override
  String get isNull => 'Là NULL';

  @override
  String get isNotNull => 'Không là NULL';

  @override
  String get exactValue => 'Giá trị chính xác';

  @override
  String get sortTable => 'Sắp xếp dữ liệu bảng';

  @override
  String get filterTable => 'Lọc dữ liệu bảng';

  @override
  String get sortRetained => 'Sắp xếp ảnh chụp lưu giữ';

  @override
  String get filterRetained => 'Lọc ảnh chụp lưu giữ';

  @override
  String get applyView => 'Áp dụng';

  @override
  String get rowsLabel => 'Hàng';

  @override
  String get fetchedRows => 'Hàng đã lấy';

  @override
  String get fixedSnapshot => 'Ảnh chụp cố định của hàng đã lấy';

  @override
  String get limitReached => 'Đạt giới hạn';

  @override
  String get retainedData => 'Dữ liệu lưu giữ';

  @override
  String get applyRequiresAutoCommit =>
      'Áp dụng và xác nhận cần phiên rảnh có bật tự động xác nhận.';

  @override
  String get connectionProfile => 'Hồ sơ kết nối';

  @override
  String get basic => 'Cơ bản';

  @override
  String get advanced => 'Nâng cao';

  @override
  String get connectionName => 'Tên';

  @override
  String get hostname => 'Tên máy chủ (cũng dùng để xác minh TLS)';

  @override
  String get port => 'Cổng';

  @override
  String get database => 'Cơ sở dữ liệu';

  @override
  String get user => 'Người dùng';

  @override
  String get password => 'Mật khẩu';

  @override
  String get writableProfile => 'Hồ sơ cho phép ghi';

  @override
  String get readonlyProfile => 'Hồ sơ chỉ đọc';

  @override
  String get tlsVerify => 'TLS: xác minh chứng chỉ và tên máy chủ';

  @override
  String get tlsInsecure => 'TLS: KHÔNG AN TOÀN, không xác minh';

  @override
  String get tlsDisabled => 'TLS: TẮT';

  @override
  String get testConnection => 'Kiểm tra không lưu';

  @override
  String get saveProfile => 'Lưu';

  @override
  String get saveConnect => 'Lưu và kết nối';

  @override
  String get sessionPassword => 'Mật khẩu chỉ cho phiên này';

  @override
  String get storedPassword =>
      'Lưu mật khẩu trong kho bảo mật của hệ điều hành';

  @override
  String get chooseFile => 'Chọn tệp';

  @override
  String get testRunning => 'Đang kiểm tra kết nối…';

  @override
  String get cancelTest => 'Hủy kiểm tra';

  @override
  String get idle => 'Không hoạt động';

  @override
  String get activeTransaction => 'Giao dịch đang mở';

  @override
  String get failedTransaction => 'Giao dịch thất bại';

  @override
  String get inspectionContext => 'Phiên kiểm tra';

  @override
  String get requireTableOrView => 'Chọn bảng hoặc khung nhìn';

  @override
  String get operationPending => 'Một thao tác tài liệu đang chờ xác nhận';

  @override
  String get requirePlan => 'Chọn lần thực thi Explain đã lưu';

  @override
  String get openPlanDocument => 'Mở tài liệu kế hoạch';

  @override
  String get locks => 'Khóa';

  @override
  String get statistics => 'Thống kê';

  @override
  String get queryStatistics => 'Thống kê truy vấn';

  @override
  String get indexDiagnostics => 'Chẩn đoán chỉ mục';

  @override
  String get grants => 'Quyền đã cấp';

  @override
  String get sqlExecution => 'Thực thi SQL';

  @override
  String get planReady => 'Kế hoạch đã lưu sẵn sàng; SQL không được chạy lại';

  @override
  String get executionPlan => 'Kế hoạch thực thi';

  @override
  String get openOwner => 'Mở chủ sở hữu';

  @override
  String get terminateActivity => 'Chấm dứt hoạt động';

  @override
  String get close => 'Đóng';

  @override
  String get previous => 'Trước';

  @override
  String get next => 'Tiếp';

  @override
  String get replaceSelection => 'Thay thế phần chọn';

  @override
  String get replaceAll => 'Thay thế tất cả';

  @override
  String get restartBackend => 'Khởi động lại tiến trình nền';

  @override
  String get structuredTree => 'Cây cấu trúc';

  @override
  String get rawOutput => 'Kết quả thô';

  @override
  String get previousTextPage => 'Trang văn bản trước';

  @override
  String get nextTextPage => 'Trang văn bản tiếp';

  @override
  String get filterChangedObjects => 'Lọc đối tượng đã đổi';

  @override
  String get rebindVerifiedEdits => 'Gắn lại thay đổi đã xác minh';

  @override
  String get discardRecoveryRecord => 'Bỏ bản ghi khôi phục';

  @override
  String get revertChange => 'Hoàn tác thay đổi đang chờ';

  @override
  String get chooseSource => 'Chọn nguồn';

  @override
  String get chooseDestination => 'Chọn đích';

  @override
  String get delimiterField => 'Dấu phân cách (một ký tự)';

  @override
  String get batchRowsField => 'Số hàng mỗi lô (1–1000)';

  @override
  String get rejectedLimit => 'Giới hạn hàng bị từ chối (1–1000)';

  @override
  String get previewSource => 'Xem trước nguồn';

  @override
  String get reviewTransfer => 'Xem xét truyền dữ liệu';

  @override
  String get startImport => 'Bắt đầu nhập';

  @override
  String get startRestore => 'Bắt đầu khôi phục';

  @override
  String get startExport => 'Bắt đầu xuất';

  @override
  String get requestCancel => 'Yêu cầu hủy';

  @override
  String get sourceMapping => 'Ánh xạ nguồn và đích';

  @override
  String get nativeTool => 'Công cụ gốc';

  @override
  String get defaultOmit => 'Bỏ qua / mặc định cơ sở dữ liệu';

  @override
  String get overwriteNever => 'Không ghi đè';

  @override
  String get overwriteExisting => 'Ghi đè tệp hiện có';

  @override
  String get planDetails => 'Chi tiết kế hoạch';

  @override
  String get planMetricsNote =>
      'Ước tính và số đo thực tế dùng tên trường của máy chủ. Số đo thiếu không có sẵn.';

  @override
  String get connected => 'Đã kết nối';

  @override
  String get disconnected => 'Đã ngắt kết nối';

  @override
  String get tables => 'Bảng';

  @override
  String get views => 'Khung nhìn';

  @override
  String get routines => 'Thủ tục';

  @override
  String get expand => 'Mở rộng';

  @override
  String get collapse => 'Thu gọn';

  @override
  String get databaseWorkbench => 'Bàn làm việc cơ sở dữ liệu';

  @override
  String get sidebar => 'Thanh bên';

  @override
  String get unchanged => 'Không thay đổi';

  @override
  String get reviewDetails => 'Chi tiết xem xét';

  @override
  String get generatedSql => 'SQL được tạo';

  @override
  String get changeReverted => 'Đã hoàn tác thay đổi. Yêu cầu xem xét lại.';

  @override
  String get unknownBatch =>
      'Kết quả chưa rõ. Lô có thể đã được xác nhận. Không bao giờ tự động phát lại; đối chiếu phiên và bản ghi khôi phục.';

  @override
  String get expiredChangeReview =>
      'Đích đã thay đổi hoặc bản xem xét đã hết hạn. Yêu cầu xem xét lại.';

  @override
  String get applyCommitExplanation =>
      'Áp dụng và xác nhận bắt đầu và xác nhận giao dịch riêng. Bảng điều khiển nguồn phải rảnh và bật tự động xác nhận. Giải quyết giao dịch SQL thủ công riêng biệt.';

  @override
  String get newRow => 'Hàng mới';

  @override
  String get original => 'Ban đầu';

  @override
  String get proposed => 'Đề xuất';

  @override
  String changeCounts(int inserts, int updates, int deletes) {
    return '$inserts chèn · $updates cập nhật · $deletes xóa';
  }

  @override
  String sourceRow(String row) {
    return 'Hàng nguồn $row';
  }

  @override
  String get refreshing => 'Đang làm mới…';

  @override
  String get refreshActivities => 'Làm mới hoạt động';

  @override
  String get explicitRefresh => 'Làm mới rõ ràng';

  @override
  String get pollFiveSeconds => 'Thăm dò mỗi 5 giây';

  @override
  String get cancelSelectedActivity => 'Hủy hoạt động đã chọn';

  @override
  String get terminateSelectedSession => 'Kết thúc phiên đã chọn';

  @override
  String get filterActivities => 'Lọc hoạt động hiện tại';

  @override
  String get blockedBy => 'Bị chặn bởi:';

  @override
  String get delete => 'Xóa';

  @override
  String get remove => 'Loại bỏ';

  @override
  String get up => 'Lên';

  @override
  String get search => 'Tìm kiếm';

  @override
  String get yes => 'Có';

  @override
  String get no => 'Không';

  @override
  String get clear => 'Xóa hết';

  @override
  String get copy => 'Sao chép';

  @override
  String get insert => 'Chèn';

  @override
  String get update => 'Cập nhật';

  @override
  String get open => 'Mở';

  @override
  String get migrationEngineMismatch =>
      'Kết nối đích phải dùng cùng hệ quản trị với các ảnh chụp được so sánh. Không hỗ trợ di chuyển giữa các hệ quản trị.';

  @override
  String get metadataContextChanged =>
      'Ngữ cảnh kiểm tra đã thay đổi. Hãy chủ động làm mới siêu dữ liệu.';

  @override
  String get newTableName => 'Tên bảng mới';

  @override
  String get routineIdentity => 'Định danh chính xác của thủ tục';

  @override
  String get objectColumnName => 'Tên đối tượng / cột';

  @override
  String get builtInType => 'Kiểu tích hợp';

  @override
  String get sqlExpression => 'Biểu thức SQL (để trống để xóa)';

  @override
  String get newPropertyValue => 'Giá trị thuộc tính mới';

  @override
  String get columnComment => 'Ghi chú cột';

  @override
  String get columnCollation =>
      'Đối chiếu cột (để trống dùng mặc định máy chủ)';

  @override
  String get addDesignedColumn => 'Thêm cột vào bảng mới';

  @override
  String get checkExpression => 'Biểu thức CHECK';

  @override
  String get referencedSchema => 'Lược đồ / cơ sở dữ liệu được tham chiếu';

  @override
  String get generating => 'Đang tạo…';

  @override
  String get generateReviewedDdl => 'Tạo DDL để duyệt';

  @override
  String get inspectCapturedDefinition => 'Kiểm tra định nghĩa đã chụp';

  @override
  String get capturedObject => 'Đối tượng đã chụp';

  @override
  String get designReviewNote =>
      'Các thay đổi được tạo để duyệt. Nội dung cơ sở dữ liệu giữ nguyên cho đến khi thực thi đã được duyệt.';

  @override
  String get columnMetadataUnavailable =>
      'Siêu dữ liệu cột không khả dụng trong phạm vi này; hãy kiểm tra lược đồ đã chọn trước khi thiết kế danh sách cột.';

  @override
  String get ordinaryColumn => 'Cột thông thường';

  @override
  String get columnWithDefault => 'Cột có giá trị mặc định';

  @override
  String get identityColumn => 'Định danh / tự tăng';

  @override
  String get generatedColumn => 'Cột được tạo';

  @override
  String get columnType => 'Kiểu cột';

  @override
  String get nullableNotNull => 'Cho phép NULL / NOT NULL';

  @override
  String get defaultExpression => 'Biểu thức mặc định';

  @override
  String get generatedExpression => 'Biểu thức được tạo';

  @override
  String get columnCollationProperty => 'Đối chiếu cột';

  @override
  String get loggedUnlogged => 'Có ghi nhật ký / không ghi nhật ký';

  @override
  String get tableComment => 'Ghi chú bảng';

  @override
  String get storageEngine => 'Bộ máy lưu trữ';

  @override
  String get tableCollation => 'Đối chiếu bảng';

  @override
  String get rowFormat => 'Định dạng hàng';

  @override
  String get createOrReplace => 'Tạo hoặc thay thế';

  @override
  String get dropSelectedObject => 'Xóa đối tượng đã chọn';

  @override
  String get addColumn => 'Thêm cột';

  @override
  String get editColumnProperties => 'Sửa thuộc tính cột';

  @override
  String get tableProperties => 'Thuộc tính bảng';

  @override
  String get triggerDefinition => 'Định nghĩa trình kích hoạt';

  @override
  String get createTable => 'Tạo bảng';

  @override
  String get viewDefinition => 'Định nghĩa khung nhìn';

  @override
  String get routineDefinition => 'Định nghĩa thủ tục';

  @override
  String get chooseExistingObject => 'Chọn đối tượng có sẵn';

  @override
  String get nullable => 'Cho phép NULL';

  @override
  String get removeIdentity => 'Xóa định danh';

  @override
  String get generatedAlways => 'Luôn được tạo';

  @override
  String get generatedByDefault => 'Được tạo mặc định / tự tăng';

  @override
  String get loggedTable => 'Bảng có ghi nhật ký';

  @override
  String get unloggedTable => 'Bảng không ghi nhật ký';

  @override
  String get orderedPrimaryKeyColumns => 'Các cột khóa chính có thứ tự';

  @override
  String get orderedColumns => 'Các cột có thứ tự';

  @override
  String get ordinaryIndex => 'Chỉ mục thông thường';

  @override
  String get uniqueIndex => 'Chỉ mục duy nhất';

  @override
  String get primaryKey => 'Khóa chính';

  @override
  String get uniqueConstraint => 'Ràng buộc duy nhất';

  @override
  String get foreignKey => 'Khóa ngoại';

  @override
  String get checkConstraint => 'Ràng buộc CHECK';

  @override
  String get immediateChecking => 'Kiểm tra ngay';

  @override
  String get deferrableChecking => 'Kiểm tra có thể trì hoãn';

  @override
  String get initiallyImmediate => 'Ban đầu kiểm tra ngay';

  @override
  String get initiallyDeferred => 'Ban đầu trì hoãn';

  @override
  String get referencedTable => 'Bảng được tham chiếu';

  @override
  String get orderedReferencedColumns =>
      'Các cột được tham chiếu theo thứ tự tương ứng';

  @override
  String get objectDefinitionEditor =>
      'Trình sửa SQL định nghĩa gốc của đối tượng';

  @override
  String get onDelete => 'Khi xóa';

  @override
  String get onUpdate => 'Khi cập nhật';

  @override
  String get stay => 'Ở lại';

  @override
  String get saveSqlClose => 'Lưu SQL và đóng';

  @override
  String get discardSqlClose => 'Bỏ SQL và đóng';

  @override
  String get closeBusyData => 'Đóng BusyData';

  @override
  String get saveDraftsClose => 'Lưu bản nháp và đóng';

  @override
  String get closeWithoutRecovery => 'Đóng không khôi phục';

  @override
  String get recoveryFailed => 'Khôi phục thất bại';

  @override
  String get discardFailedSaveClose => 'Bỏ lần lưu thất bại và đóng';

  @override
  String get closeWithoutSavingRecovery => 'Đóng không lưu khôi phục';

  @override
  String get disableSqlRecovery => 'Tắt khôi phục SQL';

  @override
  String get historyPrivacy => 'Quyền riêng tư lịch sử';

  @override
  String get enableSqlRetention => 'Bật lưu giữ SQL';

  @override
  String get disableSqlRetention => 'Tắt lưu giữ SQL';

  @override
  String get clearHistory => 'Xóa lịch sử';

  @override
  String get deleteHistoryEntry => 'Xóa mục lịch sử';

  @override
  String get deleteSelected => 'Xóa mục đã chọn';

  @override
  String get saveRetention => 'Lưu giữ';

  @override
  String get retentionDays => 'Số ngày lưu giữ';

  @override
  String get sqlTextRetained => 'Đã lưu giữ văn bản SQL';

  @override
  String get sqlTextDisabled => 'Đã tắt văn bản SQL';

  @override
  String get openHistoryQuery => 'Mở trong thẻ SQL mới';

  @override
  String get caCertificateFile => 'Tệp chứng chỉ CA';

  @override
  String get clientCertificateFile => 'Tệp chứng chỉ máy khách';

  @override
  String get clientKeyFile => 'Tệp khóa máy khách';

  @override
  String get directConnection => 'Kết nối trực tiếp';

  @override
  String get sshTunnel => 'Đường hầm SSH';

  @override
  String get sshHost => 'Máy chủ SSH';

  @override
  String get sshPort => 'Cổng SSH';

  @override
  String get sshUser => 'Người dùng SSH';

  @override
  String get reviewedKnownHosts => 'Tệp known_hosts đã xem xét';

  @override
  String get reviewSshKey => 'Xem xét khóa máy chủ SSH';

  @override
  String get changedSshKey => 'Khóa máy chủ SSH đã thay đổi';

  @override
  String get verifyFingerprint =>
      'Xác minh độc lập dấu vân tay này trước khi tin cậy.';

  @override
  String get selectedKeyPassword => 'Khóa hoặc mật khẩu đã chọn';

  @override
  String get selectedAgentIdentity => 'Danh tính tác nhân SSH đã chọn';

  @override
  String get selectedAgentSocket =>
      'Socket tác nhân Linux / ống có tên Windows đã chọn';

  @override
  String get selectedKeyFingerprint => 'Dấu vân tay khóa đã chọn · SHA256:…';

  @override
  String get selectedPrivateKey => 'Khóa riêng đã chọn (tùy chọn)';

  @override
  String get sshPassword => 'Mật khẩu SSH';

  @override
  String get keyPassphrase => 'Cụm mật khẩu khóa';

  @override
  String get connectionTimeout => 'Thời gian chờ kết nối · 1–120 giây';

  @override
  String get sqlTimeout =>
      'Hạn thực thi/lấy dữ liệu SQL · 1–3600 giây (0 = 60)';

  @override
  String get schemasEquivalent => 'Các lược đồ đã chụp tương đương.';

  @override
  String get migrationComplete =>
      'Di chuyển bao gồm các khác biệt đã chụp được hỗ trợ.';

  @override
  String get migrationPartial =>
      'Di chuyển một phần; vẫn còn khác biệt không được hỗ trợ.';

  @override
  String get differencesLimited =>
      'Hiển thị khác biệt bị giới hạn. Xem lại toàn bộ ảnh chụp đã lưu và SQL được tạo.';

  @override
  String get absent => 'Không có';

  @override
  String get definitionPreviewLimited =>
      'Xem trước định nghĩa bị giới hạn; dùng ảnh chụp gốc để có đầy đủ bằng chứng.';

  @override
  String get migrationBatchNote =>
      'SQL là một lô theo thứ tự phụ thuộc. Chọn từng đối tượng để kiểm tra, không chọn câu lệnh để áp dụng.';

  @override
  String get unsupportedLabel => 'Không được hỗ trợ';

  @override
  String get differenceAdded => 'Đã thêm';

  @override
  String get differenceRemoved => 'Đã xóa';

  @override
  String get differenceChanged => 'Đã thay đổi';

  @override
  String get selectHistoryEntry => 'Chọn một mục lịch sử';

  @override
  String get searchSqlTarget => 'Tìm SQL hoặc đích';

  @override
  String get closeSqlTab => 'Đóng thẻ SQL';

  @override
  String get historyMetadataRetained =>
      'Siêu dữ liệu trạng thái và đích vẫn còn trong lịch sử.';

  @override
  String get historyPreviewNote =>
      'Chỉ xem trước. Mở trong thẻ SQL mới để lấy văn bản được lưu giữ.';

  @override
  String get selected => 'Đã chọn';

  @override
  String get authReviewNote =>
      'Xem lại chính xác người dùng hoặc vai trò và đích trước khi áp dụng. Thông tin xác thực không bao giờ được đưa vào tài liệu SQL hoặc lịch sử. Kết nối hiện có và mật khẩu đã lưu vẫn riêng biệt.';

  @override
  String get createLogin => 'Tạo tài khoản đăng nhập';

  @override
  String get createRole => 'Tạo vai trò không đăng nhập';

  @override
  String get setPassword => 'Đặt mật khẩu';

  @override
  String get preventLogin => 'Ngăn đăng nhập mới';

  @override
  String get allowLogin => 'Cho phép đăng nhập mới';

  @override
  String get dropPrincipal => 'Xóa người dùng hoặc vai trò';

  @override
  String get principalName => 'Tên chính xác của người dùng hoặc vai trò';

  @override
  String get accountHost =>
      'Máy chủ tài khoản chính xác (ký tự đại diện mở rộng phạm vi đăng nhập)';

  @override
  String get newPassword => 'Mật khẩu mới';

  @override
  String get repeatPassword => 'Lặp lại mật khẩu mới';

  @override
  String get reviewAccount => 'Xem xét thao tác tài khoản';

  @override
  String get passwordsMismatch => 'Nhập hai lần cùng một mật khẩu không trống';

  @override
  String get accountSubmitFailed =>
      'Không thể gửi thao tác tài khoản. Kiểm tra đích, chính sách xác thực và quyền cơ sở dữ liệu.';

  @override
  String get privilegeReviewNote =>
      'Kiểm tra quyền cấp trực tiếp; SQL được tạo vẫn cần xem xét thực thi.';

  @override
  String get inspectionLimited =>
      'Giới hạn 500 hàng mỗi phần. Thu hẹp tìm kiếm; phần trống không chứng minh không có quyền truy cập thực tế.';

  @override
  String get findPrincipal => 'Tìm tên người dùng / vai trò';

  @override
  String get searchPrincipals => 'Tìm người dùng và vai trò';

  @override
  String get choosePrincipal => 'Chọn người dùng hoặc vai trò';

  @override
  String get inspectGrants => 'Kiểm tra quyền đã chọn';

  @override
  String get tablePrivileges => 'Quyền bảng / khung nhìn';

  @override
  String get schemaPrivileges => 'Quyền lược đồ';

  @override
  String get databasePrivileges => 'Quyền cơ sở dữ liệu';

  @override
  String get roleMembership => 'Thành viên vai trò';

  @override
  String get defaultRole => 'Kích hoạt vai trò mặc định';

  @override
  String get chooseGrantRole => 'Chọn vai trò để cấp / thu hồi';

  @override
  String get tableView => 'Bảng / khung nhìn';

  @override
  String get explicitPrivileges => 'Quyền rõ ràng (phân cách bằng dấu phẩy)';

  @override
  String get setDefaultRole => 'Đặt vai trò mặc định đã chọn';

  @override
  String get clearDefaultRole => 'Xóa vai trò mặc định';

  @override
  String get grantAccess => 'Cấp quyền truy cập';

  @override
  String get revokeAccess => 'Thu hồi quyền truy cập';

  @override
  String get withoutDelegation => 'Không ủy quyền';

  @override
  String get allowDelegation => 'Cho phép người nhận cấp cho người khác';

  @override
  String get readonlyChanges =>
      'Hồ sơ này chỉ đọc. Thay đổi yêu cầu phiên cho phép ghi rõ ràng.';

  @override
  String get createPrincipal => 'Tạo người dùng / vai trò';

  @override
  String get manageAuthentication => 'Quản lý xác thực đã chọn';

  @override
  String get openPrivilegeSql => 'Mở SQL quyền để xem xét';

  @override
  String get inspectPrincipalFirst =>
      'Kiểm tra người dùng hoặc vai trò đã chọn trước khi soạn thay đổi';

  @override
  String get accountAuthentication => 'Xác thực tài khoản';

  @override
  String get schema => 'Lược đồ';

  @override
  String get available => 'Có sẵn';

  @override
  String get availableEmpty => 'Có sẵn · dữ liệu trống';

  @override
  String get limitedVisibility => 'Khả năng hiển thị hoặc phạm vi hạn chế';

  @override
  String get permissionDenied => 'Bị từ chối quyền';

  @override
  String get unavailable => 'Không có sẵn';

  @override
  String get profileDisabled => 'Bị hồ sơ vô hiệu hóa';

  @override
  String get unknownState => 'Chưa rõ';

  @override
  String get inspecting => 'Đang kiểm tra…';

  @override
  String get refreshCapabilities => 'Làm mới khả năng';

  @override
  String get staleRefresh => 'Cũ · làm mới sau khi kết nối';

  @override
  String get staleContext => 'Cũ · làm mới sau khi kết nối hoặc đổi ngữ cảnh';

  @override
  String get partialTreeLimit =>
      'Một phần · đạt giới hạn cây; thu hẹp tìm kiếm đối tượng';

  @override
  String get schemaComparison => 'So sánh lược đồ';

  @override
  String get searchTable => 'Tìm bảng';

  @override
  String get focusObject => 'Tập trung';

  @override
  String get exportSvg => 'Xuất SVG';

  @override
  String get exportPng => 'Xuất PNG';

  @override
  String get diagramNotes => 'Ghi chú sơ đồ (được đưa vào SVG)';

  @override
  String get openNotes => 'Mở ghi chú';

  @override
  String get saveNotes => 'Lưu ghi chú';

  @override
  String get newSnippet => 'Đoạn SQL mới';

  @override
  String get snippetName => 'Tên đoạn SQL';

  @override
  String get saveSnippet => 'Lưu đoạn SQL';

  @override
  String get deleteSnippet => 'Xóa đoạn SQL đã lưu';

  @override
  String get insertSnippet => 'Chèn vào tài liệu SQL';

  @override
  String get snippetEditor => 'Trình sửa đoạn SQL';

  @override
  String get snippetsNote =>
      'Chèn SQL cục bộ đã lưu vào tài liệu đã chọn với hoàn tác. Thực thi vẫn phải được yêu cầu rõ ràng.';

  @override
  String get level => 'Cấp';

  @override
  String get expanded => 'mở rộng';

  @override
  String get collapsed => 'thu gọn';

  @override
  String get treeLevel => 'Cấp';

  @override
  String get retainedView => 'Khung nhìn lưu giữ';

  @override
  String get tableQuerySnapshot => 'Ảnh chụp truy vấn bảng';

  @override
  String get originalResultNote =>
      'Kết quả lưu giữ gốc; phân trang và kiểm tra không thực thi SQL';

  @override
  String get tableFilterNote =>
      'Áp dụng gửi truy vấn mới đã xem xét. Ảnh chụp trước vẫn có sẵn.';

  @override
  String get retainedFilterNote =>
      'Tất cả hàng đã lấy trong ảnh chụp cố định. SQL không chạy lại. Thứ tự lưu giữ có thể khác đối chiếu cơ sở dữ liệu.';

  @override
  String get retainedRowNote =>
      'Chọn hàng trong kết quả đã lấy. SQL không chạy lại.';

  @override
  String get copyLimitNote =>
      'Sao chép giới hạn 10.000 ô; xuất dữ liệu lưu giữ cho vùng lớn hơn.';

  @override
  String get inlineValueLimit => 'Sửa trực tiếp hỗ trợ giá trị 8KiB';

  @override
  String get editContextChanged =>
      'Phiên nguồn hoặc ngữ cảnh sửa đã đổi; kiểm tra hoặc làm mới đánh giá trước khi chuẩn bị thay đổi';

  @override
  String get editAssessmentUnavailable =>
      'Không thể sửa; làm mới đánh giá khi phiên rảnh';

  @override
  String get rowChangeReverted =>
      'Hoàn tác thay đổi hàng đang chờ; cơ sở dữ liệu không đổi';

  @override
  String get sqlCopyRequiresMetadata =>
      'Sao chép SQL cần tiến trình nền và siêu dữ liệu kiểu lưu giữ.';

  @override
  String get exportFullValue => 'Xuất toàn bộ giá trị lưu giữ';

  @override
  String valueExportReview(String bytes, String path) {
    return 'Lưu $bytes byte vào $path? Nội dung hiện có sẽ bị thay thế. SQL không chạy lại.';
  }

  @override
  String get goToRetainedRow => 'Đi tới hàng lưu giữ';

  @override
  String get row => 'Hàng';

  @override
  String get go => 'Đi';

  @override
  String get retryRows => 'Thử lại hàng lưu giữ';

  @override
  String get previousRows => 'Hàng trước';

  @override
  String get nextRows => 'Hàng tiếp';

  @override
  String get firstWindow => 'Cửa sổ lưu giữ đầu';

  @override
  String get lastWindow => 'Cửa sổ đã lấy cuối';

  @override
  String get setNull => 'Đặt NULL';

  @override
  String copyFormat(String format) {
    return 'Sao chép $format';
  }

  @override
  String get textValue => 'Văn bản';

  @override
  String get sqlValues => 'Giá trị SQL';

  @override
  String get rowSelection => 'Chọn hàng';

  @override
  String selectRow(String row) {
    return 'Chọn hàng $row';
  }

  @override
  String columnHeader(String column) {
    return 'Cột $column';
  }

  @override
  String get pendingChange => 'thay đổi đang chờ';

  @override
  String get readonlyCell => 'Ô chỉ đọc';

  @override
  String get editableCell => 'Ô có thể sửa';

  @override
  String get loadValueFirst => 'Tải giá trị lưu giữ này trước';

  @override
  String get editUnavailable => 'Không thể sửa';

  @override
  String get editCell => 'Sửa ô';

  @override
  String get unsupportedEditValue => 'Giá trị lưu giữ này chỉ hỗ trợ kiểm tra';

  @override
  String bytesCount(String bytes) {
    return '$bytes byte';
  }

  @override
  String get problems => 'Vấn đề';

  @override
  String get ownedSessions => 'Phiên sở hữu';

  @override
  String get noProblems => 'Không có vấn đề được ghi nhận';

  @override
  String get duplicateConnection => 'Nhân bản kết nối';

  @override
  String get deleteConnection => 'Xóa kết nối';

  @override
  String deleteConnectionReview(String name) {
    return 'Xóa $name? Phiên vật lý hiện có giữ nguyên thiết lập ban đầu.';
  }

  @override
  String get unresolvedSessions => 'Phiên chưa giải quyết';

  @override
  String get disconnectSessionNote =>
      'Giải quyết công việc và giao dịch đang hoạt động trước. Ngắt kết nối ảnh hưởng mọi máy khách của phiên vật lý này; không xác nhận giao dịch hoặc chạy lại SQL. Kết quả chưa rõ vẫn chưa rõ.';

  @override
  String get transferSettingsChanged => 'Thiết lập đã đổi; xem xét lại';

  @override
  String get transferReviewReady =>
      'Sẵn sàng xem xét · kiểm tra đích, phạm vi, ánh xạ và tệp';

  @override
  String get sourcePreviewNotice => 'Xem trước nguồn · chưa nhập hàng nào';

  @override
  String get transferRequiresReview => 'Xem xét đúng lần truyền này trước';

  @override
  String get transferSubmittedNotice =>
      'Đã gửi · hủy không hoàn tác giao dịch hoặc tệp đã công bố';

  @override
  String get sqlExportExecutionNote => 'Lần thực thi SQL mới đã xem xét';

  @override
  String get retainedExportSnapshotNote =>
      'Ảnh chụp đã lấy; không thực thi SQL';

  @override
  String get restorePartialCommitNote =>
      'Khôi phục có thể xác nhận một phần. Hủy không hoàn tác khôi phục.';

  @override
  String get sourcePreviewLimit => 'Xem trước nguồn · tối đa 20 hàng';

  @override
  String get importBatchSafetyNote =>
      'Lỗi hoặc hủy giữ lại các đợt đã xác nhận. Kiểm tra mã băm và nguồn bất biến trước khi gửi.';

  @override
  String get nullMarkerLiteralNote =>
      'Dấu NULL không trích dẫn; có trích dẫn là văn bản';

  @override
  String immutableSourceHash(String hash) {
    return 'SHA-256 nguồn bất biến: $hash';
  }

  @override
  String sourceColumnLabel(String column) {
    return 'Cột nguồn $column';
  }

  @override
  String previewRowLabel(String row, String column, String value) {
    return 'Hàng xem trước $row, $column: $value';
  }

  @override
  String get transferCancellationNotice => 'Đã yêu cầu hủy · chờ xác nhận';

  @override
  String transferProgress(String processed, String committed, String rejected) {
    return '$processed đã xử lý · $committed đã xác nhận · $rejected bị từ chối';
  }

  @override
  String get importAtomicPolicy => 'Mọi hàng trong một giao dịch';

  @override
  String get importBatchPolicy => 'Xác nhận theo đợt; dừng khi lỗi';

  @override
  String get importSkipPolicy => 'Bỏ qua hàng không hợp lệ; xác nhận theo đợt';

  @override
  String closeWorkCounts(
    String operations,
    String documents,
    String saves,
    String edits,
    String jobs,
    String transactions,
    String unknown,
    String sessions,
  ) {
    return 'Xác nhận/kết nối: $operations\nTài liệu chưa lưu: $documents\nĐang lưu: $saves\nThay đổi chờ: $edits\nCông việc hoạt động: $jobs\nGiao dịch cần xử lý: $transactions\nKết quả chưa rõ: $unknown\nPhiên không chắc chắn: $sessions';
  }

  @override
  String get closeDraftSaved => 'Bản nháp SQL sẽ được lưu cục bộ.';

  @override
  String get closeDraftLost =>
      'Khôi phục bị tắt; SQL và thiết kế chưa lưu sẽ mất.';

  @override
  String get closeDesignRecovery =>
      'Thiết kế dùng khôi phục riêng có giới hạn. Khi mở lại, chủ động kết nối và kiểm tra siêu dữ liệu.';

  @override
  String get closeCleanupReview =>
      'Đóng chủ phiên cuối yêu cầu hủy, hoàn tác giao dịch đã xác nhận và ngắt kết nối. Kết quả chưa rõ vẫn chưa rõ; đóng không xác nhận hay chạy lại SQL.';

  @override
  String get closeSharedSession =>
      'Máy khách khác giữ phiên vật lý dùng chung.';

  @override
  String get closeStagedRecovery =>
      'Thay đổi cần khôi phục riêng đã xác nhận, kết nối lại chủ động và xem xét mới.';

  @override
  String get closeRecoveryLoss =>
      'Không lưu được tài liệu và bố cục. Đóng có thể mất SQL và thay đổi; tệp và khôi phục cũ được giữ.';

  @override
  String get closeWaitNotice => 'Chờ xác nhận và dọn kết nối trước khi đóng.';

  @override
  String get saveFailedNotice =>
      'Lưu SQL thất bại. Giữ SQL đã sửa hoặc chủ động bỏ.';

  @override
  String get closeCleanupFailed =>
      'Dọn tiến trình nền thất bại; BusyData vẫn mở.';

  @override
  String get closeBackendUnverified =>
      'Trạng thái tiến trình nền chưa xác minh; công việc có thể còn chờ.';

  @override
  String historyRetainSqlReview(String days) {
    return 'SQL có thể chứa bí mật. Lưu văn bản trong $days ngày?';
  }

  @override
  String get historyStopSqlReview => 'Ngừng lưu SQL và xóa khỏi lịch sử cũ?';

  @override
  String get historyClearReview =>
      'Xóa toàn bộ lịch sử? Công việc hoạt động có thể ghi kết quả khi kết thúc.';

  @override
  String get historyDeleteReview => 'Xóa mục lịch sử đã chọn?';

  @override
  String get historyRetentionRange => 'Thời hạn phải là 1–3650 ngày';

  @override
  String get enableSqlHistory => 'Bật lịch sử SQL';

  @override
  String get stopSqlHistory => 'Ngừng lưu SQL';

  @override
  String get recoveryDiscardReview =>
      'Bỏ bản khôi phục? Làm rõ kết quả chưa biết trước; bỏ không hoàn tác thay đổi đã xác nhận.';

  @override
  String closeSqlSummary(String unsaved, String edits, String jobs) {
    return 'SQL chưa lưu: $unsaved\nThay đổi chờ: $edits\nCông việc hoạt động: $jobs';
  }

  @override
  String get recoveryStayOpen =>
      'Khôi phục thất bại. BusyData vẫn mở; công việc chưa lưu được giữ lại.';

  @override
  String get commitUncertaintyNote =>
      'Lỗi mạng có thể khiến kết quả xác nhận chưa rõ. Không bao giờ tự động thử lại.';

  @override
  String get closeObjectDesignDiscard =>
      'Các trường thiết kế chưa lưu sẽ bị bỏ. Tạo và lưu SQL trước để giữ thiết kế.';

  @override
  String get savePrivateDrafts => 'Lưu bản nháp khôi phục riêng';

  @override
  String get noPrivateDrafts => 'Không lưu bản nháp khôi phục';

  @override
  String shortcutField(String command) {
    return 'Phím tắt $command';
  }

  @override
  String get shortcutInvalid =>
      'Dùng phím tắt hợp lệ chưa được gán cho thao tác khác. F6 và Shift+F6 đã được dành riêng.';

  @override
  String get disableRecoveryReview =>
      'Xóa khôi phục SQL, thiết kế và thay đổi cục bộ? Công việc chưa lưu vẫn mở; sự cố có thể làm mất. Làm rõ kết quả chưa biết trước.';

  @override
  String get preferencesSaved => 'Đã lưu thiết lập';

  @override
  String get sharingSessionReview =>
      'Truy vấn dùng chung phiên vật lý, giao dịch, đối tượng tạm và thiết lập với các máy khách được liệt kê. Đóng một máy khách giữ lại các máy khác.';

  @override
  String get recoveryReconcileFirst =>
      'Giải quyết thay đổi đang áp dụng hoặc chưa rõ trước khi tắt khôi phục. Chỉ bỏ bản khôi phục qua xem xét rõ ràng riêng.';

  @override
  String get enterSearchText => 'Nhập nội dung tìm kiếm';

  @override
  String get noSearchMatches => 'Không có kết quả';

  @override
  String searchMatchCount(String position, String total) {
    return 'Kết quả $position/$total';
  }

  @override
  String get formatSqlChanged =>
      'SQL hoặc đích đã đổi. SQL gốc được giữ; yêu cầu xem trước định dạng mới.';

  @override
  String get formatSqlUnavailable =>
      'Không thể định dạng cú pháp thiếu hoặc không hỗ trợ, hoặc giới hạn phân tích. SQL gốc được giữ.';

  @override
  String get stageChange => 'Chuẩn bị thay đổi';

  @override
  String pendingChangesCount(String count) {
    return '$count thay đổi chờ; cơ sở dữ liệu chưa đổi đến khi áp dụng đã duyệt.';
  }

  @override
  String discardChangesCount(String count) {
    return 'Bỏ $count thay đổi chờ? Không gửi thao tác cơ sở dữ liệu.';
  }

  @override
  String get recoveryNoExecution =>
      'Khôi phục không kết nối, chạy SQL nguồn, tiếp tục giao dịch hay phát lại thay đổi. Bản có kết quả chưa rõ hoặc đã xác nhận không được áp dụng lại.';

  @override
  String get recoveredDesign =>
      'Đã khôi phục thiết kế. Kết nối và xem siêu dữ liệu hiện tại rõ ràng trước duyệt mới. Khôi phục không lấy SQL hay siêu dữ liệu.';

  @override
  String get retainedUnavailable =>
      'Dữ liệu lưu giữ không khả dụng. SQL đã lưu và khôi phục riêng vẫn cục bộ.';

  @override
  String get activityFingerprintNote =>
      'Dấu vân tay hoạt động được chọn được kiểm tra lại trước gửi. Ghi có thể có kết quả chưa rõ.';

  @override
  String replaceFileReview(String path) {
    return 'Thay tệp đã duyệt tại $path? Đích đổi cần duyệt mới.';
  }

  @override
  String get diagramPngSaved =>
      'Đã lưu PNG sơ đồ. Ghi chú dài hiển thị tối đa sáu dòng.';

  @override
  String get editTargetChanged =>
      'Đích sửa đã đổi. Mở lại trình sửa hàng trước khi chuẩn bị.';

  @override
  String affectedRowCount(String count) {
    return 'Số hàng bị ảnh hưởng: $count';
  }

  @override
  String get zoomIn => 'Phóng to';

  @override
  String get zoomOut => 'Thu nhỏ';

  @override
  String get resetView => 'Đặt lại chế độ xem';

  @override
  String get diagramKeys =>
      'Phím mũi tên di chuyển; + và - đổi thu phóng; Home đặt lại chế độ xem.';

  @override
  String get explorerConnected => 'Trình khám phá đã kết nối';

  @override
  String get explorerDisconnected => 'Trình khám phá đã ngắt kết nối';

  @override
  String querySessionCount(String count) {
    return 'Phiên truy vấn $count';
  }

  @override
  String get metadataColumn => 'Cột';

  @override
  String get metadataPosition => 'Vị trí';

  @override
  String get metadataUnique => 'Duy nhất';

  @override
  String get metadataJdbcType => 'Kiểu JDBC';

  @override
  String get metadataAutoIncrement => 'Tự tăng';

  @override
  String get metadataReferencedColumn => 'Cột được tham chiếu';

  @override
  String get metadataComment => 'Chú thích';

  @override
  String get metadataType => 'Kiểu';

  @override
  String get metadataEvent => 'Sự kiện';

  @override
  String get metadataSpecificName => 'Định danh gốc cụ thể';

  @override
  String get metadataOptions => 'Tùy chọn';

  @override
  String get metadataInheritance => 'Kế thừa';

  @override
  String get metadataDefinitionCaptured => 'Định nghĩa gốc đã ghi nhận';

  @override
  String get metadataDefinitionUnavailable =>
      'Không có định nghĩa trong siêu dữ liệu đã ghi nhận';

  @override
  String get metadataDefinitionUnsupported =>
      'Đối tượng đã ghi nhận không có định nghĩa gốc được hỗ trợ';

  @override
  String get connections => 'Kết nối';

  @override
  String get noConnections => 'Chưa có kết nối';

  @override
  String get startTitle => 'Kết nối cơ sở dữ liệu';

  @override
  String get startDescription =>
      'Kết nối PostgreSQL, MySQL hoặc MariaDB để duyệt đối tượng, quản lý dữ liệu và chạy truy vấn.';

  @override
  String get savedStartTitle => 'Chọn kết nối';

  @override
  String get savedStartDescription =>
      'Kết nối với kết nối đã lưu trong trình khám phá để duyệt đối tượng và chạy truy vấn.';

  @override
  String get noConnection => 'Chưa kết nối';

  @override
  String queryTitle(int number) {
    return 'Truy vấn $number';
  }

  @override
  String get sessionMenu => 'Phiên';

  @override
  String get noFilterMatches =>
      'Không có kết nối hoặc đối tượng đã tải phù hợp';

  @override
  String get activityState => 'Trạng thái';

  @override
  String get activityWait => 'Chờ';

  @override
  String get generalSettings => 'Chung';

  @override
  String get optionsSettings => 'Tùy chọn';

  @override
  String get host => 'Máy chủ';

  @override
  String get databaseSystem => 'Hệ cơ sở dữ liệu';

  @override
  String get passwordStorage => 'Lưu mật khẩu';

  @override
  String get environmentLabel => 'Môi trường';

  @override
  String get readOnlySettings => 'Chính sách chỉ đọc';

  @override
  String get tlsPolicy => 'Chính sách TLS';

  @override
  String get sshConnection => 'Kết nối SSH';

  @override
  String get sshAuthentication => 'Xác thực SSH';

  @override
  String get connectionTestAction => 'Kiểm tra kết nối';

  @override
  String get details => 'Chi tiết';

  @override
  String get copyDetails => 'Sao chép chi tiết';

  @override
  String get retry => 'Thử lại';

  @override
  String get filterCellValue => 'Lọc theo giá trị này';

  @override
  String get connectsWhenRun => 'Kết nối khi chạy';

  @override
  String get connectionSaving => 'Lưu…';

  @override
  String get connectionConnecting => 'Kết nối…';

  @override
  String get connectionCancelling => 'Hủy…';

  @override
  String get connectionSettingsChanged =>
      'Thiết lập đã thay đổi. Kiểm tra lại phiên bản này.';

  @override
  String get connectionTestChanged =>
      'Thiết lập đã thay đổi. Kiểm tra lại phiên bản này.';

  @override
  String get connectionRequired => 'Bắt buộc';

  @override
  String get connectionCorrectFields => 'Kiểm tra các thiết lập được chỉ ra.';

  @override
  String get connectionHostname =>
      'Máy chủ · Kiểm tra các thiết lập được chỉ ra.';

  @override
  String get connectionSshHostname =>
      'SSH · Máy chủ · Kiểm tra các thiết lập được chỉ ra.';

  @override
  String get connectionMaxLength => 'Tên ≤ 256';

  @override
  String get connectionTlsHelp =>
      'TLS · Máy chủ · SSH/SSL. Kiểm tra các thiết lập được chỉ ra.';

  @override
  String get connectionTlsReview =>
      'TLS · Máy chủ · SSH/SSL. Kiểm tra các thiết lập được chỉ ra.';

  @override
  String get connectionStorageUnavailable =>
      'Lưu mật khẩu: Không có sẵn. Mật khẩu · Không bao giờ.';

  @override
  String get connectionHostReviewed =>
      'Máy chủ · Tin cậy chỉ áp dụng cho hồ sơ này và đích chính xác.';

  @override
  String get connectionSshReviewing => 'SSH · Xem xét khóa máy chủ SSH…';

  @override
  String get connectionFailureAuthentication =>
      'Thất bại · Xác thực · Chung. Kiểm tra các thiết lập được chỉ ra.';

  @override
  String get connectionFailureTls =>
      'Thất bại · TLS · SSH/SSL. Kiểm tra các thiết lập được chỉ ra.';

  @override
  String get connectionFailureSshKey =>
      'Thất bại · Xem xét khóa máy chủ SSH. Kiểm tra các thiết lập được chỉ ra.';

  @override
  String get connectionFailureEndpoint =>
      'Thất bại · Máy chủ · Cổng. Kiểm tra các thiết lập được chỉ ra.';

  @override
  String get connectionFailureCancelled => 'Đã hủy';

  @override
  String get connectionFailureSettings =>
      'Thất bại · Chung. Kiểm tra các thiết lập được chỉ ra.';

  @override
  String get connectionFailureAccess =>
      'Thất bại · Quyền bảng / khung nhìn. Kiểm tra các thiết lập được chỉ ra.';

  @override
  String get connectionFailureUnavailable =>
      'Thất bại · Máy chủ · TLS · SSH. Kiểm tra các thiết lập được chỉ ra.';

  @override
  String get connectionFailureTimeout =>
      'Thất bại · Thời gian chờ kết nối · 1–120 giây. Kiểm tra các thiết lập được chỉ ra.';

  @override
  String get connectionFailureUnknown =>
      'Thất bại · Chung · TLS · SSH. Kiểm tra các thiết lập được chỉ ra.';

  @override
  String connectionNumber(int min, int max) {
    return 'Nhập số nguyên từ $min đến $max';
  }

  @override
  String connectionSavedFailure(String name) {
    return 'Đã lưu kết nối: $name. Lần kết nối thất bại. ';
  }

  @override
  String get backendBusy =>
      'Dịch vụ đang bận. Hãy đợi yêu cầu hiện tại rồi thử lại.';

  @override
  String rpcRequestUnconfirmed(String code) {
    return 'Yêu cầu chưa được xác nhận (RPC $code).';
  }

  @override
  String get operationUnconfirmed => 'Không thể hoàn tất thao tác.';

  @override
  String get connectionFailureTlsMaterial =>
      'Tài liệu TLS không có hoặc không hợp lệ. Kiểm tra nguồn tin cậy và khóa máy khách trong SSH/SSL.';

  @override
  String get managerTitle => 'Nguồn dữ liệu và trình điều khiển';

  @override
  String get sourceListTitle => 'Nguồn dữ liệu';

  @override
  String get driverLabel => 'Trình điều khiển';

  @override
  String get connectionTypeLabel => 'Kiểu kết nối';

  @override
  String get defaultTcp => 'Mặc định (TCP)';

  @override
  String get authenticationLabel => 'Xác thực';

  @override
  String get userPasswordAuth => 'Người dùng và mật khẩu';

  @override
  String get neverStorage => 'Không bao giờ';

  @override
  String get initialDatabaseLabel => 'Cơ sở dữ liệu ban đầu';

  @override
  String get useSshTunnel => 'Dùng đường hầm SSH';

  @override
  String get sshConfigurationLabel => 'Cấu hình SSH';

  @override
  String get createSshConfig => '<tạo cấu hình>';

  @override
  String get copySshSettings => 'Sao chép thiết lập SSH';

  @override
  String get localPortLabel => 'Cổng cục bộ';

  @override
  String get dynamicPortLabel => '<Động>';

  @override
  String get useSsl => 'Dùng SSL';

  @override
  String get useTruststore => 'Dùng kho tin cậy';

  @override
  String get clientKeyPasswordLabel => 'Mật khẩu khóa máy khách';

  @override
  String get modeLabel => 'Chế độ';

  @override
  String get requireTls => 'Bắt buộc';

  @override
  String get verifyCa => 'Xác minh CA';

  @override
  String get fullVerification => 'Xác minh đầy đủ';

  @override
  String get connectionSection => 'Kết nối';

  @override
  String get configurationApplied => 'Đã áp dụng cấu hình';

  @override
  String get noOtherSshConfig => 'Không có nguồn khác có cấu hình SSH.';

  @override
  String get generatedUrlHelp => 'Địa chỉ JDBC được tạo, chỉ đọc.';

  @override
  String get tlsDriverDefaultHelp =>
      'SSL chưa được cấu hình; trình điều khiển đi kèm dùng mặc định.';

  @override
  String get tlsClientKeyHelp =>
      'Khóa PEM: PKCS#8 hoặc OpenSSL; được mã hóa hoặc không mã hóa.';

  @override
  String get legacyMariaTrustHelp =>
      'Giữ nguyên xác minh hiện có của trình điều khiển. Chọn nguồn tin cậy để cấu hình chứng chỉ gốc rõ ràng.';

  @override
  String get metadataStartValue => 'Giá trị bắt đầu';

  @override
  String get metadataMinimumValue => 'Giá trị tối thiểu';

  @override
  String get metadataMaximumValue => 'Giá trị tối đa';

  @override
  String get metadataIncrement => 'Bước tăng';

  @override
  String get metadataCycle => 'Lặp vòng';

  @override
  String get metadataCacheSize => 'Kích thước bộ nhớ đệm';

  @override
  String get metadataLastValue => 'Giá trị cuối';

  @override
  String get sequences => 'Dãy số';

  @override
  String get namespaceSelection => 'Chọn không gian tên';

  @override
  String get namespaceSelectionNotice =>
      'Lựa chọn điều khiển việc kiểm tra cấu trúc. Bảng điều khiển truy vấn giữ nguyên ngữ cảnh thực thi.';

  @override
  String get allNamespaces => 'Tất cả không gian tên';

  @override
  String get defaultNamespace => 'Mặc định';

  @override
  String get namespacePattern => 'Mẫu tên (biểu thức chính quy)';

  @override
  String namespaceCount(int selected, int known) {
    return '$selected trên $known';
  }

  @override
  String get previousPage => 'Trang trước';

  @override
  String get patternRejected =>
      'Mẫu không hợp lệ hoặc vượt giới hạn công việc. Lựa chọn trước được giữ lại.';

  @override
  String get namespaceNotSelected =>
      'Không gian tên chưa được chọn để kiểm tra cấu trúc';

  @override
  String get newMenu => 'Mới';

  @override
  String get queryConsoles => 'Bảng điều khiển truy vấn';

  @override
  String get viewOptions => 'Tùy chọn hiển thị';

  @override
  String get quickDocumentation => 'Tài liệu nhanh';

  @override
  String get showEmptyGroups => 'Hiện nhóm trống';

  @override
  String get speedSearch => 'Tìm kiếm nhanh';

  @override
  String get speedSearchScope => 'Chỉ các nút đã mở rộng và tải.';

  @override
  String get newSourceFolder => 'Thư mục nguồn mới';

  @override
  String get renameSourceFolder => 'Đổi tên thư mục';

  @override
  String get moveToFolder => 'Chuyển vào thư mục';

  @override
  String get moveUp => 'Chuyển lên';

  @override
  String get moveDown => 'Chuyển xuống';

  @override
  String get folderMustBeEmpty =>
      'Di chuyển các nguồn và thư mục bên trong trước khi xóa thư mục này.';

  @override
  String get newVirtualView => 'Khung nhìn ảo mới';

  @override
  String get editVirtualDefinition => 'Sửa định nghĩa cục bộ';

  @override
  String get unboundVirtualView => 'Khung nhìn ảo chưa liên kết';

  @override
  String get localVirtualViewNotice =>
      'Định nghĩa SQL cục bộ. Lưu không chạy SQL hay tạo khung nhìn trên máy chủ. Chạy sử dụng quy trình duyệt SQL thông thường và bảng lệnh độc lập.';

  @override
  String get rebindVirtualView => 'Liên kết định nghĩa cục bộ tại đây';

  @override
  String get sourceFolderName => 'Tên thư mục';

  @override
  String get sourceFolderPathNotice => 'Dùng / để tạo thư mục lồng nhau.';

  @override
  String get topLevel => 'Cấp cao nhất';

  @override
  String get virtualViewName => 'Tên khung nhìn ảo';

  @override
  String get virtualViewSql => 'Định nghĩa SQL của khung nhìn ảo';

  @override
  String get virtualViews => 'Khung nhìn ảo';

  @override
  String get revealInExplorer => 'Hiện trong trình khám phá cơ sở dữ liệu';

  @override
  String get objectNotFound =>
      'Không tìm thấy đối tượng trong không gian tên này. Làm mới siêu dữ liệu hoặc kiểm tra quyền.';

  @override
  String get objectHiddenByFilter => 'Đối tượng bị ẩn bởi bộ lọc hiện tại.';

  @override
  String get revealFilterNotice =>
      'Tra cứu đối tượng thu hẹp trang này; tổng số của nhóm được bỏ qua.';

  @override
  String get clearObjectFilter => 'Xóa tra cứu đối tượng';

  @override
  String get compareStructure => 'So sánh cấu trúc';

  @override
  String get selectTwoCompatibleObjects =>
      'Chọn hai bảng tương thích bằng Ctrl và nhấp.';

  @override
  String get scopedComparisonRestriction =>
      'So sánh yêu cầu bảng thông thường có cùng tên gốc, lược đồ và hệ quản trị. Không hỗ trợ kiểu khác hoặc ghép tên đã đổi.';

  @override
  String get groupNamespaces => 'Nhóm cơ sở dữ liệu và lược đồ';

  @override
  String get groupSchemaObjects => 'Nhóm đối tượng lược đồ';

  @override
  String get groupTableElements => 'Nhóm thành phần bảng';

  @override
  String get sortAlphabetically => 'Sắp xếp theo bảng chữ cái';

  @override
  String get showVirtualObjects => 'Hiện đối tượng ảo';

  @override
  String get showObjectComments => 'Hiện chú thích đối tượng';

  @override
  String get objectTypeFilter => 'Bộ lọc kiểu đối tượng';

  @override
  String get partitionedTable => 'Bảng phân vùng';

  @override
  String get foreignTable => 'Bảng ngoại';

  @override
  String get materializedView => 'Khung nhìn vật hóa';

  @override
  String get functionObject => 'Hàm';

  @override
  String get procedureObject => 'Thủ tục';

  @override
  String get sqlSymbolUnavailable =>
      'Không xác định an toàn được đối tượng bền vững tại con trỏ. Kết nối bảng lệnh này và dùng tham chiếu bảng hoặc khung nhìn ngoài chuỗi và chú thích.';

  @override
  String get sqlSymbolAmbiguous =>
      'Tham chiếu đối tượng SQL không rõ ràng. Chỉ định không gian tên hoặc chọn đối tượng cơ sở dữ liệu chính xác.';

  @override
  String get deactivateSource => 'Ngắt nguồn dữ liệu';

  @override
  String get functions => 'Hàm';

  @override
  String get procedures => 'Thủ tục';

  @override
  String get separateProceduresFunctions => 'Tách thủ tục và hàm';

  @override
  String get renameVirtualView => 'Đổi tên khung nhìn ảo';

  @override
  String get metadataPersistentScope =>
      'Chỉ các đối tượng bền vững; đối tượng tạm thời hoặc cục bộ của phiên vẫn nằm trong điều hướng bảng điều khiển.';

  @override
  String get metadataSessionScope =>
      'Chỉ các đối tượng bền vững; làm mới đối tượng cục bộ của bảng điều khiển sau khi thực thi.';

  @override
  String get metadataLimitScope =>
      'Đã đạt giới hạn siêu dữ liệu. Thu hẹp phạm vi đối tượng.';

  @override
  String get completeColumnMetadataRequired =>
      'Cần có đầy đủ siêu dữ liệu cột trước khi nhập hoặc chuẩn bị thay đổi.';

  @override
  String resizeColumn(String name) {
    return 'Đổi độ rộng cột $name';
  }

  @override
  String get keyboardShortcutsHeading => 'Phím tắt';

  @override
  String sqlEditorLabel(String title) {
    return 'Trình soạn SQL $title';
  }

  @override
  String get editorResultsDivider => 'Thanh chia trình soạn và kết quả';

  @override
  String editorExtent(String percent) {
    return 'Trình soạn chiếm $percent phần trăm';
  }

  @override
  String get largerEditor => 'Mở rộng trình soạn';

  @override
  String get smallerEditor => 'Thu nhỏ trình soạn';

  @override
  String get explorerWidthDivider => 'Thanh chia độ rộng trình duyệt';

  @override
  String get widerExplorer => 'Mở rộng trình duyệt';

  @override
  String get narrowerExplorer => 'Thu hẹp trình duyệt';

  @override
  String explorerExtent(String width) {
    return 'Rộng $width điểm ảnh';
  }

  @override
  String planTextPage(String start, String end, String total) {
    return '$start–$end trên $total đơn vị UTF-16';
  }

  @override
  String get dropDesignedColumn => 'Xóa cột';

  @override
  String get liveCatalogLabel => 'Danh mục hiện tại';

  @override
  String get liveSchemaLabel => 'Lược đồ hiện tại';

  @override
  String get searchPathLabel => 'Đường dẫn tìm kiếm';

  @override
  String get physicalSessionLabel => 'Phiên vật lý';

  @override
  String queryTimeoutDetail(String seconds, String rows) {
    return 'Thời gian chờ: $seconds giây · Giới hạn hàng: $rows';
  }

  @override
  String get saveFailedCloseTitle => 'Lưu SQL thất bại · Đóng BusyData';

  @override
  String get createSection => 'Tạo';

  @override
  String get newConnectionDescription => 'Thiết lập kết nối cơ sở dữ liệu';

  @override
  String get newQueryDescription => 'Viết SQL trong truy vấn mới';

  @override
  String get openSqlDescription => 'Mở tài liệu SQL hiện có';

  @override
  String get searchNoResults => 'Không có thao tác phù hợp';

  @override
  String get actionsCategory => 'Thao tác';

  @override
  String get privateRecoveryCategory => 'Khôi phục riêng tư';

  @override
  String get shortcutRecordHelp =>
      'Nhấn phím tắt. Escape để hủy. F6 và Shift+F6 dành cho điều hướng giữa các ngăn.';

  @override
  String get rowLimitInvalid => 'Nhập giới hạn từ 1 đến 1.000.000 hàng.';

  @override
  String get errorPolicy => 'Khi thực thi gặp lỗi';

  @override
  String get tlsEncrypted => 'đã mã hóa';

  @override
  String get tlsUnencrypted => 'không mã hóa';

  @override
  String get tlsUnobserved => 'chưa quan sát';

  @override
  String get encryptionVerificationNote =>
      'Mã hóa không chứng minh việc xác minh chứng chỉ hoặc tên máy chủ.';

  @override
  String get uniqueDesignedColumnName =>
      'Dùng tên cột duy nhất; bảng mới hỗ trợ tối đa 128 cột';

  @override
  String activityBlockerUnavailable(String id) {
    return 'Phiên chặn $id không còn hiển thị; hãy làm mới và kiểm tra quyền cơ sở dữ liệu';
  }

  @override
  String get sshChangedKeyReview =>
      'Xác minh độc lập khóa đã đổi trước khi thay liên kết với hồ sơ này.';

  @override
  String get sshProfileTrustBinding =>
      'Tin cậy chỉ áp dụng cho hồ sơ này và đích chính xác.';

  @override
  String get databaseTlsEvidence => 'TLS · Hệ cơ sở dữ liệu';

  @override
  String get sshAlgorithmLabel => 'SSH · Kiểu';

  @override
  String get sshFingerprintLabel => 'SHA-256';

  @override
  String get sshPreviousFingerprintLabel => 'Trước · SHA-256';

  @override
  String get sshReviewedLabel => 'Xem xét khóa máy chủ SSH';

  @override
  String get shortcutRecordAction => 'Ghi phím tắt';

  @override
  String get fileFormatLabel => 'Định dạng tệp';

  @override
  String get encodingLabel => 'Mã hóa';

  @override
  String get importPolicyLabel => 'Chính sách nhập';

  @override
  String get mainMenu => 'Menu chính';

  @override
  String get activityReplyTooLarge =>
      'Phản hồi hoạt động vượt quá giới hạn trình kiểm tra.';

  @override
  String get activityListLimited =>
      'Danh sách bị giới hạn; kiểm tra mục tiêu hẹp hơn bằng SQL tường minh.';

  @override
  String get activitySelectionChanged =>
      'Hoạt động đã chọn đã kết thúc hoặc thay đổi. Chọn danh tính hiện tại trước khi xem xét thao tác.';

  @override
  String connectionSavedDraftChanged(String name) {
    return 'Các trường kết nối đã thay đổi trong khi lưu; cấu hình đã được lưu: $name. Hãy kiểm tra các giá trị hiện tại trước khi kết nối.';
  }

  @override
  String get sshReviewTargetChanged =>
      'Đích kiểm tra SSH đã thay đổi; hãy kiểm tra lại';

  @override
  String get appearance => 'Giao diện';

  @override
  String get theme => 'Chủ đề';

  @override
  String get systemTheme => 'Hệ thống';

  @override
  String get lightTheme => 'Sáng';

  @override
  String get darkTheme => 'Tối';

  @override
  String get appLanguage => 'Ngôn ngữ';

  @override
  String get systemLanguage => 'Hệ thống';

  @override
  String get cut => 'Cắt';

  @override
  String get paste => 'Dán';

  @override
  String get selectAll => 'Chọn tất cả';

  @override
  String get noSelection => 'Không có văn bản';

  @override
  String get clipboardEmpty => 'Bảng nhớ tạm không có văn bản';

  @override
  String get settingsDraftNotice =>
      'Chưa lưu thay đổi về thực thi và khôi phục riêng tư.';

  @override
  String get documentsMenu => 'Tài liệu';

  @override
  String get currentSql => 'SQL hiện tại';

  @override
  String get searchActionsHint => 'Tìm thao tác…';

  @override
  String get searchCurrentSqlHint => 'Search current SQL…';

  @override
  String get searchObjectsHint => 'Search database objects…';

  @override
  String get searchHistoryHint => 'Search query history…';

  @override
  String get metadataAttributes => 'Thuộc tính';

  @override
  String get metadataSelectionUnavailable =>
      'Chọn một mục để xem các thuộc tính đã ghi nhận. Lựa chọn trước không còn khả dụng.';

  @override
  String get secureStorage => 'Kho bảo mật hệ điều hành';

  @override
  String get resultPresentation => 'View as';

  @override
  String get resultTable => 'Table';

  @override
  String get resultTranspose => 'Transpose';

  @override
  String get resultTree => 'Tree';

  @override
  String get resultText => 'Text';

  @override
  String get recordView => 'Record View';

  @override
  String get valueEditor => 'Value Editor';

  @override
  String get aggregateView => 'Aggregate View';

  @override
  String get relatedRows => 'Related Rows';

  @override
  String get cloneRow => 'Clone Row';

  @override
  String get displayFormat => 'Display format';

  @override
  String get canonicalValue => 'Canonical / raw';

  @override
  String get groupedNumber => 'Numeric grouping';

  @override
  String get jsonPretty => 'JSON formatted text';

  @override
  String get binaryHex => 'Binary hexadecimal';

  @override
  String get binaryBase64 => 'Binary Base64';

  @override
  String get uuidPresentation => 'UUID (16 bytes)';

  @override
  String get wrapText => 'Wrap text';

  @override
  String get selectedCellsScope => 'Selected cells only';

  @override
  String get retainedWindowScope => 'Current retained window only';

  @override
  String get serverDataOperations => 'Server-side table sorting and filtering';

  @override
  String get localDataOperations =>
      'Local sorting and filtering of retained data';

  @override
  String get partialRetainedScope =>
      'Partial retained result; this view does not represent the complete server table.';

  @override
  String get valueComplete => 'Complete retained value';

  @override
  String get valueTruncated =>
      'Truncated preview; the complete value is retained.';

  @override
  String get loadValueChunk => 'Load next 64 KiB';

  @override
  String get resetValueChunks => 'Reset value preview';

  @override
  String get structuredParseError =>
      'Structured interpretation is unavailable; exact raw content remains accessible.';

  @override
  String get structuredValueLimit =>
      'Structured display is limited to 256 KiB, 4,096 nodes and 32 levels.';

  @override
  String valueChunkRange(String start, String end, String total) {
    return 'Bytes $start–$end of $total';
  }

  @override
  String get presentationScopeLimit =>
      'This presentation exceeds its bounded scope. Select fewer cells or use Export.';

  @override
  String get transposeSelectionLimit =>
      'Transpose shows at most 32 selected rows. Narrow the selection to inspect another range.';

  @override
  String get jsonTree => 'JSON tree';

  @override
  String get xmlInterpretation => 'XML interpretation';

  @override
  String get imagePreview => 'Image preview';

  @override
  String get imagePreviewUnavailable =>
      'Image preview requires recognized image bytes within the 1 MiB / 4 megapixel limit.';

  @override
  String get valueDraftLimit =>
      'Value drafts exceed the shared 1 MiB text / 2 MiB complete-value limit. Stage or discard another draft first.';

  @override
  String get valueDraftPreserved =>
      'Value draft preserved; stored value is unchanged.';

  @override
  String get setDefault => 'Set DEFAULT';

  @override
  String get assignmentUnset => 'Unchanged / unset';

  @override
  String get assignmentValue => 'Exact value';

  @override
  String get assignmentNull => 'SQL NULL';

  @override
  String get assignmentDefault => 'Server DEFAULT';

  @override
  String get originalValue => 'Original value';

  @override
  String get stagedValue => 'Staged value';

  @override
  String get noRelatedRows =>
      'No available relationships for this retained row.';

  @override
  String get aggregateSelectedCount => 'Selected count';

  @override
  String get aggregateNonNull => 'Non-NULL count';

  @override
  String get aggregateNull => 'NULL count';

  @override
  String get aggregateDistinct => 'Distinct count';

  @override
  String get aggregateSum => 'Sum';

  @override
  String get aggregateAverage => 'Average';

  @override
  String get aggregateMinimum => 'Minimum';

  @override
  String get aggregateMaximum => 'Maximum';

  @override
  String get aggregateStoredValues =>
      'Aggregates use original retained values; staged edits are excluded.';

  @override
  String get relatedRowsUnavailable =>
      'Related-row navigation requires complete metadata and verified retained provenance.';

  @override
  String get stagedInsertReview =>
      'Clone staged as an insert. Review and edit its assignments before Apply.';

  @override
  String get rawValue => 'Raw value';

  @override
  String get previousRecord => 'Previous record';

  @override
  String get nextRecord => 'Next record';

  @override
  String get binaryInputError =>
      'Enter complete hexadecimal bytes or valid Base64 for the selected binary mode.';

  @override
  String get valueChunkEncoding =>
      'This byte page begins or ends inside a UTF-8 character. Use hexadecimal or export the complete value.';

  @override
  String get copyDisplayedText => 'Copy displayed text';

  @override
  String get requiredColumn => 'NOT NULL';

  @override
  String get editStagedInserts => 'Edit staged inserts';

  @override
  String get metadataSettings => 'Metadata and introspection';

  @override
  String get metadataIncludeCatalogs =>
      'Included databases (one exact name per line; empty uses current database)';

  @override
  String get metadataExcludeCatalogs => 'Excluded databases';

  @override
  String get metadataIncludeSchemas =>
      'Included schemas (empty uses current resolution path)';

  @override
  String get metadataExcludeSchemas => 'Excluded schemas';

  @override
  String get metadataIncludePatterns => 'Included object patterns';

  @override
  String get metadataExcludePatterns => 'Excluded object patterns';

  @override
  String get metadataSystemObjects => 'Include system objects';

  @override
  String get metadataDefaultLevel => 'Default introspection level';

  @override
  String get metadataLevelNames => 'Names and identities';

  @override
  String get metadataLevelStructure => 'Structure';

  @override
  String get metadataLevelSource => 'Structure and source';

  @override
  String get metadataFullRefresh => 'Full refresh';

  @override
  String get metadataIncrementalRefresh => 'Incremental refresh';

  @override
  String get metadataScopeLevels =>
      'Scope levels: catalog / schema / level, one per line';

  @override
  String get metadataCacheState => 'Cache state';

  @override
  String get metadataConfigurationChanged =>
      'Metadata configuration changed; reopen to review current settings';

  @override
  String get metadataAddScope => 'Add scope level';

  @override
  String get metadataAddName => 'Add exact name';

  @override
  String get metadataObjectKinds => 'Object kinds';

  @override
  String get metadataLastRefresh => 'Last successful refresh';

  @override
  String get metadataPatternsNote =>
      'Patterns use * for any characters and ? for one character. Names remain exact database identifiers.';

  @override
  String get sqlLanguage => 'SQL language';

  @override
  String get sqlDialect => 'SQL dialect';

  @override
  String get sqlPostgresql => 'PostgreSQL';

  @override
  String get sqlMysql => 'MySQL';

  @override
  String get sqlMariadb => 'MariaDB';

  @override
  String get sqlPreferenceScope => 'Settings scope';

  @override
  String get sqlDialectDefaults => 'Dialect defaults';

  @override
  String get sqlDialectDefaultsDescription =>
      'Applies to SQL documents using this dialect unless their connection has an override.';

  @override
  String get sqlProfileOverrideDescription =>
      'Applies only to SQL documents owned by the selected connection.';

  @override
  String get sqlUseDialectDefaults =>
      'Use dialect defaults for this connection';

  @override
  String get sqlFormatting => 'SQL formatting';

  @override
  String get sqlKeywordCase => 'Keyword case';

  @override
  String get sqlPreserveCase => 'Preserve case';

  @override
  String get sqlUpperCase => 'Uppercase';

  @override
  String get sqlLowerCase => 'Lowercase';

  @override
  String get sqlIndentationWidth => 'Indentation width';

  @override
  String get sqlContinuationIndent => 'Continuation indentation';

  @override
  String get sqlClauseBreaks => 'Start clauses on new lines';

  @override
  String get sqlJoinLayout => 'JOIN layout';

  @override
  String get sqlNewLine => 'New line';

  @override
  String get sqlSameLine => 'Same line';

  @override
  String get sqlCommaPlacement => 'Comma placement';

  @override
  String get sqlLeading => 'Leading';

  @override
  String get sqlTrailing => 'Trailing';

  @override
  String get sqlLogicalPlacement => 'Logical operator placement';

  @override
  String get sqlWrapLists => 'Wrap field and assignment lists';

  @override
  String get sqlWrapArguments => 'Wrap function arguments';

  @override
  String get sqlIndentSubqueries => 'Indent subqueries';

  @override
  String get sqlCteBreaks => 'Separate common table expressions';

  @override
  String get sqlParenthesisSpacing => 'Space inside parentheses';

  @override
  String get sqlOperatorSpacing => 'Space around operators';

  @override
  String get sqlAlignment => 'Align wrapped assignments';

  @override
  String get sqlMaximumLine => 'Maximum line length';

  @override
  String get sqlPreserveBlankLines => 'Preserve intentional blank lines';

  @override
  String get sqlInspections => 'SQL inspections';

  @override
  String get sqlInspectionDisabled => 'Disabled';

  @override
  String get sqlSeverityError => 'Error';

  @override
  String get sqlSeverityWarning => 'Warning';

  @override
  String get sqlSeverityInformation => 'Information';

  @override
  String get sqlSeverityHint => 'Hint';

  @override
  String get sqlInspectionUpdateWhere => 'UPDATE without WHERE';

  @override
  String get sqlInspectionDeleteWhere => 'DELETE without WHERE';

  @override
  String get sqlInspectionRelation => 'Unresolved relation';

  @override
  String get sqlInspectionColumn => 'Unresolved column';

  @override
  String get sqlInspectionAmbiguous => 'Ambiguous column';

  @override
  String get sqlInspectionDerived => 'Invalid derived-table column';

  @override
  String get sqlInspectionDuplicateAlias => 'Duplicate relation alias';

  @override
  String get sqlInspectionDuplicateCte => 'Duplicate common table expression';

  @override
  String get sqlInspectionDuplicateInsert => 'Duplicate INSERT column';

  @override
  String get sqlInspectionInsertTarget => 'Unknown INSERT target column';

  @override
  String get sqlInspectionUpdateTarget => 'Unknown UPDATE target column';

  @override
  String get sqlInspectionArguments => 'Invalid routine argument count';

  @override
  String get sqlInspectionOverload => 'No matching routine overload';

  @override
  String get sqlInspectionAggregate => 'Invalid aggregate or window expression';

  @override
  String get sqlInspectionComparison => 'Incompatible comparison types';

  @override
  String get sqlInspectionAssignment => 'Incompatible assignment type';

  @override
  String get parameterInformation => 'Parameter information';

  @override
  String activeArgument(int index) {
    return 'Active argument: $index';
  }

  @override
  String get numericScale2 => 'Numeric grouping · 2 decimal places';

  @override
  String get numericScale4 => 'Numeric grouping · 4 decimal places';

  @override
  String get temporalDate => 'Temporal date · yyyy-MM-dd';

  @override
  String get temporalTime => 'Temporal time · ISO';

  @override
  String get temporalUtc => 'Timestamp · UTC (requires explicit offset)';

  @override
  String get temporalLocal =>
      'Timestamp · local timezone (requires explicit offset)';

  @override
  String get formatCurrentStatement => 'Format current statement';

  @override
  String get completionLimited =>
      'More matches are available. Type a longer prefix.';

  @override
  String get parameterInformationLimited =>
      'More overloads exist; parameter information is limited.';

  @override
  String get sqlInspectionSyntax => 'SQL syntax error';

  @override
  String get sqlInspectionDialect =>
      'SQL construct is unavailable for this dialect';

  @override
  String get sqlInspectionUnavailable =>
      'SQL analysis is unavailable for this construct';

  @override
  String get sqlInspectionUnknownFunction => 'Unknown routine';

  @override
  String get sqlInspectionMetadata =>
      'SQL inspection is incomplete because metadata is unavailable';

  @override
  String get sqlDiagnosticsEmpty =>
      'No SQL inspections were reported for this document.';

  @override
  String sqlDiagnosticSpan(int start, int end, String source) {
    return 'UTF-16 $start–$end · $source';
  }

  @override
  String get sqlDiagnosticGo => 'Go to SQL span';

  @override
  String get sqlDiagnosticFix => 'Apply selected correction';

  @override
  String get sqlDiagnosticReplacement => 'Replacement text';

  @override
  String get sqlDiagnosticStale =>
      'SQL inspection context changed. Request inspections again.';

  @override
  String get sqlDiagnosticUnavailable =>
      'SQL inspections are unavailable for the current document.';

  @override
  String sqlDiagnosticCount(int count) {
    return '$count SQL inspections';
  }

  @override
  String get aggregateTextOrder =>
      'Text minimum/maximum use retained UTF-16 ordinal order; database collation is not applied.';

  @override
  String get aggregateMixedTypes =>
      'The selected values have incompatible types. Select values with a common type.';

  @override
  String get aggregateUnsupportedOrder =>
      'Ordering and numeric calculations are unavailable for this value type.';

  @override
  String get relatedKeyNotProjected =>
      'Select all relationship key columns in the source result before navigating.';

  @override
  String get relatedNullKey =>
      'A NULL relationship key has no matching related row.';

  @override
  String get relatedTargetUnavailable =>
      'The relationship target is outside this session’s supported database scope.';

  @override
  String get relatedValueLimited =>
      'The relationship key is truncated or exceeds navigation limits. Browse the target explicitly.';

  @override
  String get temporalCustomPattern => 'Temporal · custom pattern';

  @override
  String get temporalPattern => 'Temporal display pattern';

  @override
  String get temporalSourceZone => 'Original calendar fields';

  @override
  String get temporalZone => 'Display timezone';

  @override
  String get temporalPatternHelp =>
      'Use ICU calendar fields and up to six S digits for exact fractions. UTC/local conversion requires an explicit offset. Unsupported temporal values remain raw.';

  @override
  String get temporalPatternInvalid =>
      'Use a pattern of 1–128 characters with supported calendar fields, balanced quotes, and at most six S digits. Timezone letters z, Z and v are unsupported; choose the display timezone separately.';

  @override
  String get editCompleteValue => 'Edit complete value';

  @override
  String get completeValueEditLimit =>
      'Complete editing requires verified retained ownership, at most 1 MiB across original and new values, and 262,144 text units per value. Larger values remain available for export.';

  @override
  String get completeValueReady =>
      'Complete retained value loaded for editing; changes are staged only.';

  @override
  String get binaryNextEditPage => 'Next 16 KiB';

  @override
  String get binaryPreviousEditPage => 'Previous 16 KiB';

  @override
  String get arrayEditLimit =>
      'Array edits use exact native PostgreSQL text, at most 16 KiB of text, six dimensions and 1,024 scalar values. Java validates the captured element type.';

  @override
  String get valueChangedDuringStage =>
      'The earlier value was staged. Your newer draft is preserved; review it before staging again.';

  @override
  String textValuePage(String current, String total) {
    return 'Text page $current of $total';
  }

  @override
  String get textValuePagesScope =>
      'Only this text page is shown. Copy and export actions keep their stated scope.';

  @override
  String get textValueEditScope => 'Stage change includes every text page.';

  @override
  String get textValuePreviousPage => 'Previous text page';

  @override
  String get textValueNextPage => 'Next text page';

  @override
  String get valuePageEditLimit =>
      'That text is invalid or too large for this page. The previous text was kept.';

  @override
  String get valueAddEditPage => 'Add editing page';

  @override
  String get binaryAppendPageReason =>
      'Finish a valid, full last binary page before adding another page. Bytes are never padded.';

  @override
  String get valueEditorActions => 'Value actions';

  @override
  String get utf8Hex => 'UTF-8 hexadecimal';

  @override
  String get utf8Base64 => 'UTF-8 Base64';

  @override
  String get nativeTextNulUnavailable =>
      'Plain text editing is unavailable for values containing a NUL character. UTF-8 byte views and exact export remain available.';

  @override
  String get textClipboardNulUnavailable =>
      'This text contains a NUL character and cannot be copied exactly. Export the value or choose another extractor.';

  @override
  String sqlVisibleLine(int line, int total, int column) {
    return 'Visible SQL line $line of $total, column $column';
  }

  @override
  String get sqlLinePreviewTruncated => 'Line preview truncated';

  @override
  String sqlActiveCarets(int count) {
    return '$count carets active';
  }

  @override
  String get sqlCompositionActive => 'Input composition active';

  @override
  String get sqlEditorDocumentLimit =>
      'The edit exceeds the 8M UTF-16 document limit. Use a smaller document.';

  @override
  String get sqlEditorLineLimit =>
      'The edit exceeds the 100,000-line document limit. Use a smaller document.';

  @override
  String get sqlEditorCaretLimit =>
      'The editor supports at most 64 carets. Remove extra carets before adding more.';

  @override
  String get sqlEditorFinishComposition =>
      'Finish input composition before changing this selection.';

  @override
  String get sqlEditorClipboardLimit =>
      'The exact selection exceeds the 1 MiB clipboard limit. Save or export the text instead.';

  @override
  String get sqlEditorSelectionUnavailable =>
      'The editor cannot apply this selection. The original SQL is retained.';

  @override
  String get sqlEditorClipboardUnavailable =>
      'The clipboard is unavailable. Your SQL and selection have been kept.';

  @override
  String get metadataCacheWriteUnavailable =>
      'Không thể lưu bộ nhớ đệm. Siêu dữ liệu hiện tại vẫn khả dụng.';

  @override
  String get metadataCacheRebuiltVersion =>
      'Đã dựng lại cho phiên bản hiện tại';

  @override
  String get metadataCacheRebuiltCorrupt => 'Đã dựng lại sau lỗi bộ nhớ đệm';

  @override
  String get editSessionBusy =>
      'Phiên này đang bận. Hãy chờ tác vụ hiện tại hoàn tất, rồi yêu cầu đánh giá lại khả năng chỉnh sửa.';

  @override
  String get editIdentityRequired =>
      'Trước khi chỉnh sửa, hãy chọn đầy đủ khóa chính hoặc định danh duy nhất không cho phép NULL.';

  @override
  String get editColumnsReadOnly =>
      'Tất cả các cột được chiếu đều là cột được tạo hoặc chỉ đọc.';

  @override
  String get editResultNotReady =>
      'Hãy chờ kết quả được giữ lại này hoàn tất trước khi yêu cầu đánh giá lại khả năng chỉnh sửa.';

  @override
  String get editProjectionUnsupported =>
      'Việc chỉnh sửa yêu cầu SELECT trực tiếp từ một bảng gốc, trong đó mỗi cột gốc chỉ được chọn một lần.';

  @override
  String get sqlInspectionDuplicateUsingColumn => 'Cột JOIN USING bị trùng';

  @override
  String get sqlInspectionUnresolvedUsingColumn =>
      'Một toán hạng thiếu cột JOIN USING';

  @override
  String get sqlInspectionAmbiguousUsingColumn =>
      'Cột chung của JOIN không rõ ràng';

  @override
  String get sqlInspectionOutputColumnCount =>
      'Số cột đầu ra đã khai báo không khớp';

  @override
  String get sqlInspectionAmbiguousOverload =>
      'Nạp chồng chương trình con không rõ ràng';

  @override
  String get sqlInspectionBooleanType => 'Kiểu biểu thức Boolean không hợp lệ';

  @override
  String get sqlInspectionOperatorTypes =>
      'Kiểu toán hạng của toán tử không tương thích';

  @override
  String get sqlInspectionArrayTypes => 'Kiểu phần tử mảng không tương thích';

  @override
  String get sqlInspectionCaseConditionType =>
      'Kiểu điều kiện CASE không tương thích';

  @override
  String get sqlInspectionCaseResultTypes =>
      'Kiểu kết quả CASE không tương thích';

  @override
  String get sqlInspectionCoalesceTypes =>
      'Kiểu đối số COALESCE không tương thích';

  @override
  String get sqlInspectionSetColumnCount =>
      'Số cột của phép toán tập hợp không khớp';

  @override
  String get sqlInspectionSetTypes =>
      'Kiểu kết quả phép toán tập hợp không tương thích';

  @override
  String get sqlInspectionRecursiveCteType => 'Kiểu CTE đệ quy không khớp';
}
