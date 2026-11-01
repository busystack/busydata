// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Korean (`ko`).
class AppLocalizationsKo extends AppLocalizations {
  AppLocalizationsKo([String locale = 'ko']) : super(locale);

  @override
  String get cancel => '취소';

  @override
  String get windowMinimize => '최소화';

  @override
  String get windowMaximize => '최대화';

  @override
  String get windowRestore => '복원';

  @override
  String get databaseExplorer => '데이터베이스 탐색기';

  @override
  String get databases => '데이터베이스';

  @override
  String get newConnection => '새 연결';

  @override
  String get filterTree => '연결 및 객체 필터';

  @override
  String get treeFilterScope => '불러온 트리 개체를 필터링합니다';

  @override
  String get searchObjects => '데이터베이스 개체 검색';

  @override
  String get fileMenu => '파일';

  @override
  String get editMenu => '편집';

  @override
  String get viewMenu => '보기';

  @override
  String get connectionMenu => '연결';

  @override
  String get objectMenu => '개체';

  @override
  String get runMenu => '실행 옵션';

  @override
  String get commands => '명령';

  @override
  String get findCommand => '명령 검색';

  @override
  String get newSql => '새 쿼리';

  @override
  String get openSql => 'SQL 열기';

  @override
  String get openSqlFile => 'SQL 파일 열기';

  @override
  String get saveSql => 'SQL 저장';

  @override
  String get closeTab => '탭 닫기';

  @override
  String get openWorkspace => '작업 공간 열기';

  @override
  String get saveWorkspace => '작업 공간 저장';

  @override
  String get settings => '설정';

  @override
  String get findText => '찾기';

  @override
  String get replaceText => '바꾸기';

  @override
  String get formatSql => 'SQL 서식 지정';

  @override
  String get lineComments => '줄 주석 전환';

  @override
  String get snippets => 'SQL 코드 조각';

  @override
  String get run => '실행';

  @override
  String get runStatement => '현재 문 실행';

  @override
  String get runSelection => '선택 영역 실행';

  @override
  String get runScript => '스크립트 실행';

  @override
  String get explain => '실행 계획';

  @override
  String get explainAnalyze => '실행 후 계획 분석';

  @override
  String get connect => '연결';

  @override
  String get disconnect => '연결 끊기';

  @override
  String get sessionDetails => '세션 세부 정보';

  @override
  String get beginTransaction => '트랜잭션 시작';

  @override
  String get commitTransaction => '트랜잭션 커밋';

  @override
  String get rollbackTransaction => '트랜잭션 롤백';

  @override
  String get enableAutoCommit => '자동 커밋 사용';

  @override
  String get disableAutoCommit => '자동 커밋 해제';

  @override
  String get outcomeUnknown => '결과 알 수 없음';

  @override
  String get outcomeUnknownNote =>
      '작업이 완료되었을 수 있습니다. 이 세션에서는 더 이상 SQL을 실행할 수 없습니다. 자동으로 재시도하지 말고 새 작업을 시작하기 전에 결과를 확인하세요.';

  @override
  String get notConnected => '연결 끊김';

  @override
  String get autoCommit => '자동 커밋';

  @override
  String get manualTransaction => '수동 트랜잭션';

  @override
  String get readOnlyPolicy => 'BusyData 읽기 전용 정책';

  @override
  String get data => '데이터';

  @override
  String get structure => '구조';

  @override
  String get results => '결과';

  @override
  String get messages => '메시지';

  @override
  String get plan => '계획';

  @override
  String get changes => '변경 사항';

  @override
  String get history => '기록';

  @override
  String get jobs => '작업';

  @override
  String get retainedResults => '보존된 결과';

  @override
  String get recoverEdits => '준비된 변경 복구';

  @override
  String get applyAndCommit => '적용하고 커밋';

  @override
  String get inspectStructure => '구조 검사';

  @override
  String get openData => '데이터 열기';

  @override
  String get openDefinition => '정의 열기';

  @override
  String get copyQualifiedName => '정규화된 이름 복사';

  @override
  String get refresh => '새로 고침';

  @override
  String get columns => '열';

  @override
  String get indexes => '인덱스';

  @override
  String get constraints => '키 및 제약 조건';

  @override
  String get foreignKeys => '외래 키';

  @override
  String get triggers => '트리거';

  @override
  String get definition => '정의';

  @override
  String get dependencies => '종속성';

  @override
  String get connectionCapabilities => '연결 개요';

  @override
  String get sessionsAndLocks => '세션 및 잠금';

  @override
  String get usersAndRoles => '사용자 및 역할';

  @override
  String get saveSnapshot => '스키마 스냅샷 저장';

  @override
  String get compareSchemas => '스키마 비교';

  @override
  String get objectDesigner => '개체 디자이너';

  @override
  String get diagram => 'ER 다이어그램';

  @override
  String get backup => '백업';

  @override
  String get restore => '복원';

  @override
  String get importData => '데이터 가져오기';

  @override
  String get exportRetained => '보존된 데이터 내보내기';

  @override
  String get exportSql => 'SQL 내보내기 실행';

  @override
  String get stageInsert => '행 삽입';

  @override
  String get stageUpdate => '행 편집';

  @override
  String get stageDelete => '행 삭제';

  @override
  String get discardChanges => '보류 중인 변경 취소';

  @override
  String get disposeResult => '보존된 데이터 해제';

  @override
  String get currentSchema => '현재 스키마(변경 대상)';

  @override
  String get desiredSchema => '원하는 스키마';

  @override
  String get applyTo => '적용 대상';

  @override
  String get loading => '불러오는 중';

  @override
  String get empty => '이 범위에 개체가 없습니다';

  @override
  String get more => '더 보기';

  @override
  String get filter => '필터';

  @override
  String get sort => '정렬';

  @override
  String get selectTarget => '연결 선택';

  @override
  String get requireSql => 'SQL 문서가 필요합니다';

  @override
  String get requireSession => '상태가 확인된 연결된 세션이 필요합니다';

  @override
  String get requireResult => '보존된 데이터가 필요합니다';

  @override
  String get requireObject => '대상 개체가 필요합니다';

  @override
  String get cancelRequested => '취소 요청됨';

  @override
  String get cancelled => '취소됨';

  @override
  String get queued => '대기 중';

  @override
  String get running => '실행 중';

  @override
  String get completed => '완료됨';

  @override
  String get failed => '실패';

  @override
  String get partial => '부분';

  @override
  String get sessionSharing => '기존 세션 공유(고급)';

  @override
  String get production => '운영';

  @override
  String get staging => '스테이징';

  @override
  String get development => '개발';

  @override
  String get executionOptions => '실행 옵션';

  @override
  String get resultRowLimit => '결과 행 제한(1–1000000)';

  @override
  String get boundedRead => '제한된 읽기';

  @override
  String get streamingRead => '스트리밍 읽기 · 읽기 트랜잭션 보유';

  @override
  String get stopOnError => '오류 발생 시 스크립트 중지';

  @override
  String get continueOnError => '오류 발생 시 계속 · 이전 문은 이미 커밋되었을 수 있음';

  @override
  String get loadMore => '더 불러오기';

  @override
  String get favorite => '즐겨찾기 전환';

  @override
  String get connectionGroup => '연결 그룹';

  @override
  String get copyRange => '범위 복사';

  @override
  String get inspectValue => '값 검사';

  @override
  String get editConnection => '연결 편집';

  @override
  String get chooseSnapshot => '스냅샷 선택';

  @override
  String get captureSchema => '스키마 캡처';

  @override
  String get sameSchemaRestriction =>
      '스냅샷의 엔진, 스키마 이름 및 버전이 같아야 합니다. 비교와 저장은 변경을 적용하지 않습니다.';

  @override
  String get restoredTaskState =>
      '문서 참조를 복원했습니다. 이전 백엔드 데이터, 세션 및 작업은 사용할 수 없습니다. 명시적 동작으로 새 작업을 시작하세요. 복원은 연결하거나 SQL을 실행하거나 변경을 다시 적용하지 않습니다.';

  @override
  String get preChangeSnapshot =>
      '변경 전 스냅샷 · 변경이 커밋되었습니다. 현재 행과 서버 기본값을 검사하려면 명시적으로 새로 고침하세요.';

  @override
  String get sqlProvenance => 'SQL 출처';

  @override
  String get assessEditing => '편집 가능 여부 확인';

  @override
  String get viewDetails => '세부 정보 보기';

  @override
  String get gridMenu => '데이터 그리드';

  @override
  String get visibleColumns => '표시할 열';

  @override
  String get hidden => '숨김';

  @override
  String get ascending => '오름차순';

  @override
  String get descending => '내림차순';

  @override
  String get equals => '같음';

  @override
  String get notEqual => '같지 않음';

  @override
  String get lessThan => '보다 작음';

  @override
  String get greaterThan => '보다 큼';

  @override
  String get isNull => 'NULL임';

  @override
  String get isNotNull => 'NULL이 아님';

  @override
  String get exactValue => '정확한 값';

  @override
  String get sortTable => '테이블 데이터 정렬';

  @override
  String get filterTable => '테이블 데이터 필터';

  @override
  String get sortRetained => '보관된 스냅샷 정렬';

  @override
  String get filterRetained => '보관된 스냅샷 필터';

  @override
  String get applyView => '적용';

  @override
  String get rowsLabel => '행';

  @override
  String get fetchedRows => '가져온 행';

  @override
  String get fixedSnapshot => '가져온 행의 고정 스냅샷';

  @override
  String get limitReached => '제한 도달';

  @override
  String get retainedData => '보관된 데이터';

  @override
  String get applyRequiresAutoCommit => '적용 및 커밋에는 자동 커밋이 켜진 유휴 세션이 필요합니다.';

  @override
  String get connectionProfile => '연결 프로필';

  @override
  String get basic => '기본';

  @override
  String get advanced => '고급';

  @override
  String get connectionName => '이름';

  @override
  String get hostname => '호스트 이름(TLS 검증에도 사용)';

  @override
  String get port => '포트';

  @override
  String get database => '데이터베이스';

  @override
  String get user => '사용자';

  @override
  String get password => '비밀번호';

  @override
  String get writableProfile => '쓰기가 가능한 프로필';

  @override
  String get readonlyProfile => '읽기 전용 프로필';

  @override
  String get tlsVerify => 'TLS: 인증서 및 호스트 이름 검증';

  @override
  String get tlsInsecure => 'TLS: 안전하지 않음, 검증 안 함';

  @override
  String get tlsDisabled => 'TLS: 비활성화';

  @override
  String get testConnection => '저장하지 않고 테스트';

  @override
  String get saveProfile => '저장';

  @override
  String get saveConnect => '저장 후 연결';

  @override
  String get sessionPassword => '이 세션만의 비밀번호';

  @override
  String get storedPassword => 'OS 보안 저장소에 비밀번호 저장';

  @override
  String get chooseFile => '파일 선택';

  @override
  String get testRunning => '연결 테스트 중…';

  @override
  String get cancelTest => '테스트 취소';

  @override
  String get idle => '유휴';

  @override
  String get activeTransaction => '트랜잭션 열림';

  @override
  String get failedTransaction => '트랜잭션 실패';

  @override
  String get inspectionContext => '검사 세션';

  @override
  String get requireTableOrView => '테이블 또는 뷰 선택';

  @override
  String get operationPending => '문서 작업이 확인 응답을 기다리고 있습니다';

  @override
  String get requirePlan => '보관된 Explain 실행 선택';

  @override
  String get openPlanDocument => '계획 문서 열기';

  @override
  String get locks => '잠금';

  @override
  String get statistics => '통계';

  @override
  String get queryStatistics => '쿼리 통계';

  @override
  String get indexDiagnostics => '인덱스 진단';

  @override
  String get grants => '부여된 권한';

  @override
  String get sqlExecution => 'SQL 실행';

  @override
  String get planReady => '보관된 계획이 준비되었습니다. SQL은 다시 실행되지 않았습니다';

  @override
  String get executionPlan => '실행 계획';

  @override
  String get openOwner => '소유자 열기';

  @override
  String get terminateActivity => '활동 종료';

  @override
  String get close => '닫기';

  @override
  String get previous => '이전';

  @override
  String get next => '다음';

  @override
  String get replaceSelection => '선택 영역 바꾸기';

  @override
  String get replaceAll => '모두 바꾸기';

  @override
  String get restartBackend => '백엔드 다시 시작';

  @override
  String get structuredTree => '구조 트리';

  @override
  String get rawOutput => '원시 출력';

  @override
  String get previousTextPage => '이전 텍스트 페이지';

  @override
  String get nextTextPage => '다음 텍스트 페이지';

  @override
  String get filterChangedObjects => '변경된 개체 필터';

  @override
  String get rebindVerifiedEdits => '검증된 편집 다시 연결';

  @override
  String get discardRecoveryRecord => '복구 기록 버리기';

  @override
  String get revertChange => '대기 중인 변경 되돌리기';

  @override
  String get chooseSource => '원본 선택';

  @override
  String get chooseDestination => '대상 선택';

  @override
  String get delimiterField => '구분 문자 (한 문자)';

  @override
  String get batchRowsField => '배치당 행 (1–1000)';

  @override
  String get rejectedLimit => '거부된 행 한도 (1–1000)';

  @override
  String get previewSource => '원본 미리 보기';

  @override
  String get reviewTransfer => '전송 검토';

  @override
  String get startImport => '가져오기 시작';

  @override
  String get startRestore => '복원 시작';

  @override
  String get startExport => '내보내기 시작';

  @override
  String get requestCancel => '취소 요청';

  @override
  String get sourceMapping => '원본 및 대상 매핑';

  @override
  String get nativeTool => '네이티브 도구';

  @override
  String get defaultOmit => '생략 / 데이터베이스 기본값';

  @override
  String get overwriteNever => '덮어쓰지 않음';

  @override
  String get overwriteExisting => '기존 파일 덮어쓰기';

  @override
  String get planDetails => '계획 세부 정보';

  @override
  String get planMetricsNote =>
      '추정값과 실제 측정값은 서버의 필드 이름을 사용합니다. 누락된 측정값은 사용할 수 없습니다.';

  @override
  String get connected => '연결됨';

  @override
  String get disconnected => '연결 끊김';

  @override
  String get tables => '테이블';

  @override
  String get views => '뷰';

  @override
  String get routines => '루틴';

  @override
  String get expand => '펼치기';

  @override
  String get collapse => '접기';

  @override
  String get databaseWorkbench => '데이터베이스 작업 공간';

  @override
  String get sidebar => '사이드바';

  @override
  String get unchanged => '변경 없음';

  @override
  String get reviewDetails => '검토 세부 정보';

  @override
  String get generatedSql => '생성된 SQL';

  @override
  String get changeReverted => '보류 중인 변경을 되돌렸습니다. 새 검토를 요청하세요.';

  @override
  String get unknownBatch =>
      '결과를 알 수 없습니다. 배치가 커밋되었을 수 있습니다. 자동으로 다시 실행하지 말고 세션과 복구 기록을 확인하세요.';

  @override
  String get expiredChangeReview => '대상이 변경되었거나 검토가 만료되었습니다. 새 검토를 요청하세요.';

  @override
  String get applyCommitExplanation =>
      '적용 및 커밋은 자체 트랜잭션을 시작하고 커밋합니다. 원본 콘솔은 자동 커밋이 켜진 유휴 상태여야 합니다. 수동 SQL 트랜잭션은 별도로 해결하세요.';

  @override
  String get newRow => '새 행';

  @override
  String get original => '원본';

  @override
  String get proposed => '제안';

  @override
  String changeCounts(int inserts, int updates, int deletes) {
    return '삽입 $inserts · 업데이트 $updates · 삭제 $deletes';
  }

  @override
  String sourceRow(String row) {
    return '원본 행 $row';
  }

  @override
  String get refreshing => '새로 고치는 중…';

  @override
  String get refreshActivities => '활동 새로 고침';

  @override
  String get explicitRefresh => '명시적 새로 고침';

  @override
  String get pollFiveSeconds => '5초마다 조회';

  @override
  String get cancelSelectedActivity => '선택한 활동 취소';

  @override
  String get terminateSelectedSession => '선택한 세션 종료';

  @override
  String get filterActivities => '현재 활동 필터링';

  @override
  String get blockedBy => '차단 주체:';

  @override
  String get delete => '삭제';

  @override
  String get remove => '삭제';

  @override
  String get up => '위로';

  @override
  String get search => '검색';

  @override
  String get yes => '예';

  @override
  String get no => '아니오';

  @override
  String get clear => '지우기';

  @override
  String get copy => '복사';

  @override
  String get insert => '삽입';

  @override
  String get update => '갱신';

  @override
  String get open => '열기';

  @override
  String get migrationEngineMismatch =>
      '적용 대상 연결은 비교한 스냅샷과 같은 엔진을 사용해야 합니다. 다른 엔진 간 마이그레이션은 지원하지 않습니다.';

  @override
  String get metadataContextChanged =>
      '검사 컨텍스트가 변경되었습니다. 메타데이터를 명시적으로 새로 고치세요.';

  @override
  String get newTableName => '새 테이블 이름';

  @override
  String get routineIdentity => '루틴의 정확한 식별 정보';

  @override
  String get objectColumnName => '개체 / 열 이름';

  @override
  String get builtInType => '기본 제공 형식';

  @override
  String get sqlExpression => 'SQL 식 (비워 두면 삭제)';

  @override
  String get newPropertyValue => '새 속성 값';

  @override
  String get columnComment => '열 주석';

  @override
  String get columnCollation => '열 정렬 규칙 (비워 두면 서버 기본값)';

  @override
  String get addDesignedColumn => '새 테이블에 열 추가';

  @override
  String get checkExpression => 'CHECK 식';

  @override
  String get referencedSchema => '참조하는 스키마 / 데이터베이스';

  @override
  String get generating => '생성 중…';

  @override
  String get generateReviewedDdl => '검토할 DDL 생성';

  @override
  String get inspectCapturedDefinition => '캡처한 정의 검사';

  @override
  String get capturedObject => '캡처한 개체';

  @override
  String get designReviewNote =>
      '변경 사항은 검토를 위해 생성됩니다. 검토한 실행 전까지 데이터베이스 내용은 변경되지 않습니다.';

  @override
  String get columnMetadataUnavailable =>
      '이 범위의 열 메타데이터를 사용할 수 없습니다. 열 목록을 설계하기 전에 선택한 스키마를 검사하세요.';

  @override
  String get ordinaryColumn => '일반 열';

  @override
  String get columnWithDefault => '기본값이 있는 열';

  @override
  String get identityColumn => 'ID / 자동 증가';

  @override
  String get generatedColumn => '생성된 열';

  @override
  String get columnType => '열 형식';

  @override
  String get nullableNotNull => 'NULL 허용 / NOT NULL';

  @override
  String get defaultExpression => '기본값 식';

  @override
  String get generatedExpression => '생성 식';

  @override
  String get columnCollationProperty => '열 정렬 규칙';

  @override
  String get loggedUnlogged => '로그됨 / 로그되지 않음';

  @override
  String get tableComment => '테이블 주석';

  @override
  String get storageEngine => '스토리지 엔진';

  @override
  String get tableCollation => '테이블 정렬 규칙';

  @override
  String get rowFormat => '행 형식';

  @override
  String get createOrReplace => '만들기 또는 바꾸기';

  @override
  String get dropSelectedObject => '선택한 개체 삭제';

  @override
  String get addColumn => '열 추가';

  @override
  String get editColumnProperties => '열 속성 편집';

  @override
  String get tableProperties => '테이블 속성';

  @override
  String get triggerDefinition => '트리거 정의';

  @override
  String get createTable => '테이블 만들기';

  @override
  String get viewDefinition => '뷰 정의';

  @override
  String get routineDefinition => '루틴 정의';

  @override
  String get chooseExistingObject => '기존 개체 선택';

  @override
  String get nullable => 'NULL 허용';

  @override
  String get removeIdentity => 'ID 제거';

  @override
  String get generatedAlways => '항상 생성';

  @override
  String get generatedByDefault => '기본적으로 생성 / 자동 증가';

  @override
  String get loggedTable => '로그된 테이블';

  @override
  String get unloggedTable => '로그되지 않은 테이블';

  @override
  String get orderedPrimaryKeyColumns => '순서가 있는 기본 키 열';

  @override
  String get orderedColumns => '순서가 있는 열';

  @override
  String get ordinaryIndex => '일반 인덱스';

  @override
  String get uniqueIndex => '고유 인덱스';

  @override
  String get primaryKey => '기본 키';

  @override
  String get uniqueConstraint => '고유 제약 조건';

  @override
  String get foreignKey => '외래 키';

  @override
  String get checkConstraint => 'CHECK 제약 조건';

  @override
  String get immediateChecking => '즉시 검사';

  @override
  String get deferrableChecking => '지연 가능한 검사';

  @override
  String get initiallyImmediate => '처음에 즉시';

  @override
  String get initiallyDeferred => '처음에 지연';

  @override
  String get referencedTable => '참조하는 테이블';

  @override
  String get orderedReferencedColumns => '일치하는 순서의 참조 열';

  @override
  String get objectDefinitionEditor => '기본 개체 정의 SQL 편집기';

  @override
  String get onDelete => '삭제 시';

  @override
  String get onUpdate => '업데이트 시';

  @override
  String get stay => '계속 머물기';

  @override
  String get saveSqlClose => 'SQL 저장 후 닫기';

  @override
  String get discardSqlClose => 'SQL 버리고 닫기';

  @override
  String get closeBusyData => 'BusyData 닫기';

  @override
  String get saveDraftsClose => '초안 저장 후 닫기';

  @override
  String get closeWithoutRecovery => '복구 없이 닫기';

  @override
  String get recoveryFailed => '복구 실패';

  @override
  String get discardFailedSaveClose => '실패한 저장 버리고 닫기';

  @override
  String get closeWithoutSavingRecovery => '복구 저장 없이 닫기';

  @override
  String get disableSqlRecovery => 'SQL 복구 비활성화';

  @override
  String get historyPrivacy => '기록 개인정보 보호';

  @override
  String get enableSqlRetention => 'SQL 보존 활성화';

  @override
  String get disableSqlRetention => 'SQL 보존 비활성화';

  @override
  String get clearHistory => '기록 지우기';

  @override
  String get deleteHistoryEntry => '기록 항목 삭제';

  @override
  String get deleteSelected => '선택 항목 삭제';

  @override
  String get saveRetention => '보존 저장';

  @override
  String get retentionDays => '보존 일수';

  @override
  String get sqlTextRetained => 'SQL 텍스트 보존됨';

  @override
  String get sqlTextDisabled => 'SQL 텍스트 비활성화됨';

  @override
  String get openHistoryQuery => '새 SQL 탭에서 열기';

  @override
  String get caCertificateFile => 'CA 인증서 파일';

  @override
  String get clientCertificateFile => '클라이언트 인증서 파일';

  @override
  String get clientKeyFile => '클라이언트 키 파일';

  @override
  String get directConnection => '직접 연결';

  @override
  String get sshTunnel => 'SSH 터널';

  @override
  String get sshHost => 'SSH 호스트';

  @override
  String get sshPort => 'SSH 포트';

  @override
  String get sshUser => 'SSH 사용자';

  @override
  String get reviewedKnownHosts => '검토한 known_hosts 파일';

  @override
  String get reviewSshKey => 'SSH 호스트 키 검토';

  @override
  String get changedSshKey => 'SSH 호스트 키 변경됨';

  @override
  String get verifyFingerprint => '신뢰하기 전에 이 지문을 독립적으로 확인하세요.';

  @override
  String get selectedKeyPassword => '선택한 키 또는 암호';

  @override
  String get selectedAgentIdentity => '선택한 SSH 에이전트 ID';

  @override
  String get selectedAgentSocket => '선택한 Linux 에이전트 소켓 / Windows 명명된 파이프';

  @override
  String get selectedKeyFingerprint => '선택한 키 지문 · SHA256:…';

  @override
  String get selectedPrivateKey => '선택한 개인 키 (선택 사항)';

  @override
  String get sshPassword => 'SSH 암호';

  @override
  String get keyPassphrase => '키 암호 문구';

  @override
  String get connectionTimeout => '연결 시간 제한 · 1–120초';

  @override
  String get sqlTimeout => 'SQL 실행/가져오기 기한 · 1–3600초 (0 = 60)';

  @override
  String get schemasEquivalent => '캡처한 스키마가 동등합니다.';

  @override
  String get migrationComplete => '마이그레이션이 지원되는 캡처 차이를 포함합니다.';

  @override
  String get migrationPartial => '부분 마이그레이션입니다. 지원되지 않는 차이가 남습니다.';

  @override
  String get differencesLimited => '차이 표시가 제한됩니다. 저장한 전체 스냅샷과 생성 SQL을 검토하세요.';

  @override
  String get absent => '없음';

  @override
  String get definitionPreviewLimited =>
      '정의 미리 보기가 제한됩니다. 전체 근거는 원본 스냅샷을 사용하세요.';

  @override
  String get migrationBatchNote =>
      'SQL은 종속성 순서의 단일 배치입니다. 개별 개체 선택은 검사 목적이며 적용할 문을 선택하지 않습니다.';

  @override
  String get unsupportedLabel => '지원되지 않음';

  @override
  String get differenceAdded => '추가됨';

  @override
  String get differenceRemoved => '제거됨';

  @override
  String get differenceChanged => '변경됨';

  @override
  String get selectHistoryEntry => '기록 항목 선택';

  @override
  String get searchSqlTarget => 'SQL 또는 대상 검색';

  @override
  String get closeSqlTab => 'SQL 탭 닫기';

  @override
  String get historyMetadataRetained => '상태 및 대상 메타데이터는 기록에 남습니다.';

  @override
  String get historyPreviewNote =>
      '미리 보기만 표시합니다. 보존한 텍스트를 가져오려면 새 SQL 탭에서 여세요.';

  @override
  String get selected => '선택됨';

  @override
  String get authReviewNote =>
      '적용 전에 정확한 사용자 또는 역할과 대상을 검토하세요. 자격 증명은 SQL 문서나 기록에 저장되지 않습니다. 기존 연결과 저장한 암호는 별도로 유지됩니다.';

  @override
  String get createLogin => '로그인 계정 만들기';

  @override
  String get createRole => '로그인 없는 역할 만들기';

  @override
  String get setPassword => '암호 설정';

  @override
  String get preventLogin => '새 로그인 방지';

  @override
  String get allowLogin => '새 로그인 허용';

  @override
  String get dropPrincipal => '사용자 또는 역할 삭제';

  @override
  String get principalName => '정확한 사용자 또는 역할 이름';

  @override
  String get accountHost => '정확한 계정 호스트 (와일드카드는 로그인 범위를 넓힘)';

  @override
  String get newPassword => '새 암호';

  @override
  String get repeatPassword => '새 암호 반복';

  @override
  String get reviewAccount => '계정 작업 검토';

  @override
  String get passwordsMismatch => '비어 있지 않은 같은 암호를 두 번 입력하세요';

  @override
  String get accountSubmitFailed =>
      '계정 작업을 제출하지 못했습니다. 대상, 인증 정책 및 데이터베이스 권한을 확인하세요.';

  @override
  String get privilegeReviewNote =>
      '직접 부여한 권한을 검사하세요. 생성 SQL은 계속 실행 검토가 필요합니다.';

  @override
  String get inspectionLimited =>
      '섹션당 500행으로 제한됩니다. 검색 범위를 좁히세요. 빈 섹션은 실제 접근 권한이 없음을 입증하지 않습니다.';

  @override
  String get findPrincipal => '사용자 / 역할 이름 찾기';

  @override
  String get searchPrincipals => '사용자 및 역할 검색';

  @override
  String get choosePrincipal => '사용자 또는 역할 선택';

  @override
  String get inspectGrants => '선택한 권한 검사';

  @override
  String get tablePrivileges => '테이블 / 뷰 권한';

  @override
  String get schemaPrivileges => '스키마 권한';

  @override
  String get databasePrivileges => '데이터베이스 권한';

  @override
  String get roleMembership => '역할 구성원 자격';

  @override
  String get defaultRole => '기본 역할 활성화';

  @override
  String get chooseGrantRole => '부여 / 취소할 역할 선택';

  @override
  String get tableView => '테이블 / 뷰';

  @override
  String get explicitPrivileges => '명시적 권한 (쉼표로 구분)';

  @override
  String get setDefaultRole => '선택한 기본 역할 설정';

  @override
  String get clearDefaultRole => '기본 역할 지우기';

  @override
  String get grantAccess => '접근 허용';

  @override
  String get revokeAccess => '접근 취소';

  @override
  String get withoutDelegation => '위임 없음';

  @override
  String get allowDelegation => '받는 사용자가 다른 사람에게 부여하도록 허용';

  @override
  String get readonlyChanges => '이 프로필은 읽기 전용입니다. 변경에는 명시적으로 쓰기 가능한 세션이 필요합니다.';

  @override
  String get createPrincipal => '사용자 / 역할 만들기';

  @override
  String get manageAuthentication => '선택한 인증 관리';

  @override
  String get openPrivilegeSql => '검토할 권한 SQL 열기';

  @override
  String get inspectPrincipalFirst => '변경 작성 전에 선택한 사용자 또는 역할을 검사하세요';

  @override
  String get accountAuthentication => '계정 인증';

  @override
  String get schema => '스키마';

  @override
  String get available => '사용 가능';

  @override
  String get availableEmpty => '사용 가능 · 데이터 없음';

  @override
  String get limitedVisibility => '제한된 가시성 또는 범위';

  @override
  String get permissionDenied => '권한 거부됨';

  @override
  String get unavailable => '사용 불가';

  @override
  String get profileDisabled => '프로필에 의해 비활성화됨';

  @override
  String get unknownState => '알 수 없음';

  @override
  String get inspecting => '검사 중…';

  @override
  String get refreshCapabilities => '기능 새로 고침';

  @override
  String get staleRefresh => '오래된 정보 · 연결 후 새로 고침';

  @override
  String get staleContext => '오래된 정보 · 연결 또는 컨텍스트 변경 후 새로 고침';

  @override
  String get partialTreeLimit => '일부 · 트리 한도 도달. 데이터베이스 개체 검색 범위를 좁히세요';

  @override
  String get schemaComparison => '스키마 비교';

  @override
  String get searchTable => '테이블 검색';

  @override
  String get focusObject => '포커스';

  @override
  String get exportSvg => 'SVG 내보내기';

  @override
  String get exportPng => 'PNG 내보내기';

  @override
  String get diagramNotes => '다이어그램 메모 (SVG에 포함)';

  @override
  String get openNotes => '메모 열기';

  @override
  String get saveNotes => '메모 저장';

  @override
  String get newSnippet => '새 코드 조각';

  @override
  String get snippetName => '코드 조각 이름';

  @override
  String get saveSnippet => '코드 조각 저장';

  @override
  String get deleteSnippet => '저장된 코드 조각 삭제';

  @override
  String get insertSnippet => 'SQL 문서에 삽입';

  @override
  String get snippetEditor => 'SQL 코드 조각 편집기';

  @override
  String get snippetsNote =>
      '저장된 로컬 SQL을 캡처한 문서에 실행 취소 가능하게 삽입합니다. 실행은 명시적으로 해야 합니다.';

  @override
  String get level => '수준';

  @override
  String get expanded => '펼쳐짐';

  @override
  String get collapsed => '접힘';

  @override
  String get treeLevel => '수준';

  @override
  String get retainedView => '보존된 뷰';

  @override
  String get tableQuerySnapshot => '테이블 쿼리 스냅샷';

  @override
  String get originalResultNote => '원본 보존 결과. 페이지 이동과 검사는 SQL을 실행하지 않습니다';

  @override
  String get tableFilterNote => '적용은 검토된 새 데이터베이스 쿼리를 제출합니다. 이전 스냅샷은 유지됩니다.';

  @override
  String get retainedFilterNote =>
      '고정 스냅샷의 모든 가져온 행. SQL은 재실행되지 않습니다. 보존 값 순서는 데이터베이스 정렬 규칙과 다를 수 있습니다.';

  @override
  String get retainedRowNote => '이미 가져온 결과 내 행을 선택하세요. SQL은 재실행되지 않습니다.';

  @override
  String get copyLimitNote => '복사는 10,000셀로 제한됩니다. 큰 범위는 보존 데이터를 내보내세요.';

  @override
  String get inlineValueLimit => '셀 내 편집은 8KiB 값을 지원합니다';

  @override
  String get editContextChanged =>
      '원본 세션 또는 편집 컨텍스트가 변경되었습니다. 변경 준비 전에 평가를 검사하거나 새로 고치세요';

  @override
  String get editAssessmentUnavailable =>
      '편집 여부를 확인할 수 없습니다. 세션이 유휴일 때 평가를 새로 고치세요';

  @override
  String get rowChangeReverted => '대기 중인 행 변경을 되돌렸습니다. 데이터베이스는 변경되지 않았습니다';

  @override
  String get sqlCopyRequiresMetadata => 'SQL 복사에는 백엔드와 보존된 형식 메타데이터가 필요합니다.';

  @override
  String get exportFullValue => '보존된 전체 값 내보내기';

  @override
  String valueExportReview(String bytes, String path) {
    return '$bytes바이트를 $path에 저장할까요? 기존 내용이 바뀝니다. SQL은 재실행되지 않습니다.';
  }

  @override
  String get goToRetainedRow => '보존된 행으로 이동';

  @override
  String get row => '행';

  @override
  String get go => '이동';

  @override
  String get retryRows => '보존된 행 다시 시도';

  @override
  String get previousRows => '이전 행';

  @override
  String get nextRows => '다음 행';

  @override
  String get firstWindow => '첫 보존 창';

  @override
  String get lastWindow => '마지막 가져온 창';

  @override
  String get setNull => 'NULL 설정';

  @override
  String copyFormat(String format) {
    return '$format 복사';
  }

  @override
  String get textValue => '텍스트';

  @override
  String get sqlValues => 'SQL 값';

  @override
  String get rowSelection => '행 선택';

  @override
  String selectRow(String row) {
    return '행 $row 선택';
  }

  @override
  String columnHeader(String column) {
    return '열 $column';
  }

  @override
  String get pendingChange => '대기 중인 변경';

  @override
  String get readonlyCell => '읽기 전용 셀';

  @override
  String get editableCell => '편집 가능한 셀';

  @override
  String get loadValueFirst => '이 보존 값을 먼저 로드하세요';

  @override
  String get editUnavailable => '편집할 수 없음';

  @override
  String get editCell => '셀 편집';

  @override
  String get unsupportedEditValue => '이 보존 값은 검사만 지원합니다';

  @override
  String bytesCount(String bytes) {
    return '$bytes바이트';
  }

  @override
  String get problems => '문제';

  @override
  String get ownedSessions => '소유 세션';

  @override
  String get noProblems => '기록된 문제 없음';

  @override
  String get duplicateConnection => '연결 복제';

  @override
  String get deleteConnection => '연결 삭제';

  @override
  String deleteConnectionReview(String name) {
    return '$name을 삭제할까요? 기존 물리 세션은 원래 설정을 유지합니다.';
  }

  @override
  String get unresolvedSessions => '미해결 세션';

  @override
  String get disconnectSessionNote =>
      '먼저 활성 작업과 트랜잭션을 해결하세요. 연결 해제는 이 물리 세션의 모든 클라이언트에 영향을 줍니다. 커밋하거나 SQL을 재실행하지 않습니다. 알 수 없는 결과는 그대로 유지됩니다.';

  @override
  String get transferSettingsChanged => '설정이 변경되었습니다. 다시 검토하세요';

  @override
  String get transferReviewReady => '검토 준비됨 · 대상, 범위, 매핑과 파일 확인';

  @override
  String get sourcePreviewNotice => '소스 미리 보기 · 가져온 행 없음';

  @override
  String get transferRequiresReview => '먼저 이 전송을 검토하세요';

  @override
  String get transferSubmittedNotice => '제출됨 · 취소는 커밋이나 게시된 파일을 되돌리지 않습니다';

  @override
  String get sqlExportExecutionNote => '새로 검토된 SQL 실행';

  @override
  String get retainedExportSnapshotNote => '가져온 스냅샷; SQL을 실행하지 않습니다';

  @override
  String get restorePartialCommitNote =>
      '복원은 일부 커밋될 수 있습니다. 취소는 복원을 되돌리지 않습니다.';

  @override
  String get sourcePreviewLimit => '소스 미리 보기 · 최대 20행';

  @override
  String get importBatchSafetyNote =>
      '오류나 취소에도 이전 배치 커밋은 유지됩니다. 제출 전에 해시와 변경 불가 소스를 검증합니다.';

  @override
  String get nullMarkerLiteralNote => '따옴표 없는 NULL 표시; 따옴표 안에서는 일반 텍스트';

  @override
  String immutableSourceHash(String hash) {
    return '변경 불가 소스 SHA-256: $hash';
  }

  @override
  String sourceColumnLabel(String column) {
    return '소스 열 $column';
  }

  @override
  String previewRowLabel(String row, String column, String value) {
    return '미리 보기 행 $row, $column: $value';
  }

  @override
  String get transferCancellationNotice => '취소 요청됨 · 확인 대기';

  @override
  String transferProgress(String processed, String committed, String rejected) {
    return '$processed 처리 · $committed 커밋 · $rejected 거부';
  }

  @override
  String get importAtomicPolicy => '모든 행을 하나의 트랜잭션으로';

  @override
  String get importBatchPolicy => '배치 커밋; 오류 시 중지';

  @override
  String get importSkipPolicy => '잘못된 행 건너뛰기; 배치 커밋';

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
    return '확인/연결: $operations\n저장하지 않은 문서: $documents\n저장 중: $saves\n대기 변경: $edits\n활성 작업: $jobs\n정리할 트랜잭션: $transactions\n알 수 없는 결과: $unknown\n불확실한 세션: $sessions';
  }

  @override
  String get closeDraftSaved => 'SQL 초안을 로컬에 저장합니다.';

  @override
  String get closeDraftLost => '복구가 꺼져 있습니다. 저장하지 않은 SQL과 설계는 손실됩니다.';

  @override
  String get closeDesignRecovery =>
      '설계는 비공개 제한 복구를 사용합니다. 다시 열 때 명시적으로 연결하고 메타데이터를 검사하세요.';

  @override
  String get closeCleanupReview =>
      '마지막 세션 소유자를 닫으면 취소를 요청하고 확인된 트랜잭션을 롤백하며 연결을 해제합니다. 알 수 없는 결과는 그대로입니다. 닫기는 SQL을 커밋하거나 재실행하지 않습니다.';

  @override
  String get closeSharedSession => '다른 클라이언트는 공유 물리 세션을 유지합니다.';

  @override
  String get closeStagedRecovery => '변경에는 확인된 비공개 복구, 명시적 재연결과 새 검토가 필요합니다.';

  @override
  String get closeRecoveryLoss =>
      '문서와 레이아웃을 저장하지 못했습니다. 닫으면 SQL과 변경이 손실될 수 있습니다. 기존 파일과 복구 데이터는 유지합니다.';

  @override
  String get closeWaitNotice => '닫기 전에 확인과 연결 정리를 기다리세요.';

  @override
  String get saveFailedNotice => 'SQL 저장 실패. 변경된 SQL을 유지하거나 명시적으로 버리세요.';

  @override
  String get closeCleanupFailed => '백엔드 정리 실패. BusyData가 열린 채로 유지됩니다.';

  @override
  String get closeBackendUnverified => '백엔드 상태 미확인. 작업이 남아 있을 수 있습니다.';

  @override
  String historyRetainSqlReview(String days) {
    return 'SQL에 비밀 정보가 있을 수 있습니다. 텍스트를 $days일 보관할까요?';
  }

  @override
  String get historyStopSqlReview => 'SQL 저장을 중지하고 기존 기록에서 제거할까요?';

  @override
  String get historyClearReview => '모든 기록을 삭제할까요? 활성 작업은 끝날 때 결과를 기록할 수 있습니다.';

  @override
  String get historyDeleteReview => '선택한 기록을 삭제할까요?';

  @override
  String get historyRetentionRange => '보관 기간은 1–3650일이어야 합니다';

  @override
  String get enableSqlHistory => 'SQL 기록 켜기';

  @override
  String get stopSqlHistory => 'SQL 보관 중지';

  @override
  String get recoveryDiscardReview =>
      '복구 기록을 버릴까요? 알 수 없는 결과를 먼저 해결하세요. 버리기는 커밋된 변경을 되돌리지 않습니다.';

  @override
  String closeSqlSummary(String unsaved, String edits, String jobs) {
    return '저장하지 않은 SQL: $unsaved\n대기 변경: $edits\n활성 작업: $jobs';
  }

  @override
  String get recoveryStayOpen =>
      '복구 실패. BusyData가 열린 채로 유지되며 저장하지 않은 작업은 보존됩니다.';

  @override
  String get commitUncertaintyNote =>
      '네트워크 오류로 커밋 결과를 알 수 없을 수 있습니다. 자동으로 재시도하지 마세요.';

  @override
  String get closeObjectDesignDiscard =>
      '저장하지 않은 설계 필드를 버립니다. 설계를 유지하려면 먼저 SQL을 생성하고 저장하세요.';

  @override
  String get savePrivateDrafts => '비공개 복구 초안 저장';

  @override
  String get noPrivateDrafts => '복구 초안 저장 안 함';

  @override
  String shortcutField(String command) {
    return '$command 바로 가기';
  }

  @override
  String get shortcutInvalid =>
      '다른 작업에 할당되지 않은 유효한 단축키를 사용하세요. F6 및 Shift+F6은 예약되어 있습니다.';

  @override
  String get disableRecoveryReview =>
      '로컬 SQL, 설계와 변경 복구를 삭제할까요? 저장하지 않은 작업은 열린 상태지만 충돌로 손실될 수 있습니다. 알 수 없는 결과를 먼저 해결하세요.';

  @override
  String get preferencesSaved => '설정 저장됨';

  @override
  String get sharingSessionReview =>
      '쿼리는 지정한 물리 세션, 트랜잭션, 임시 객체와 설정을 나열된 클라이언트와 공유합니다. 하나를 닫아도 나머지는 유지됩니다.';

  @override
  String get recoveryReconcileFirst =>
      '복구를 끄기 전에 적용 중이거나 알 수 없는 변경을 해결하세요. 복구 기록은 명시적 개별 검토로만 버리세요.';

  @override
  String get enterSearchText => '검색 텍스트 입력';

  @override
  String get noSearchMatches => '일치 항목 없음';

  @override
  String searchMatchCount(String position, String total) {
    return '$total개 중 $position번째';
  }

  @override
  String get formatSqlChanged =>
      'SQL이나 대상이 바뀌었습니다. 원본 SQL은 유지됩니다. 새 서식 미리보기를 요청하세요.';

  @override
  String get formatSqlUnavailable =>
      '불완전하거나 지원되지 않는 구문 또는 분석 한도로 서식을 지정할 수 없습니다. 원본 SQL은 유지됩니다.';

  @override
  String get stageChange => '변경 준비';

  @override
  String pendingChangesCount(String count) {
    return '대기 변경 $count개. 검토한 적용까지 데이터베이스는 바뀌지 않습니다.';
  }

  @override
  String discardChangesCount(String count) {
    return '대기 변경 $count개를 버릴까요? 데이터베이스 작업은 제출하지 않습니다.';
  }

  @override
  String get recoveryNoExecution =>
      '복구는 연결, 원본 SQL 실행, 트랜잭션 재개, 변경 재실행을 하지 않습니다. 결과 미상이나 커밋한 기록은 다시 적용할 수 없습니다.';

  @override
  String get recoveredDesign =>
      '설계 복구됨. 명시적으로 연결하고 현재 메타데이터를 확인한 후 새 검토를 만드세요. 복원 중 SQL이나 메타데이터를 가져오지 않았습니다.';

  @override
  String get retainedUnavailable =>
      '보관 데이터를 사용할 수 없습니다. 저장 SQL과 비공개 복구는 로컬에 남습니다.';

  @override
  String get activityFingerprintNote =>
      '선택 활동의 지문을 제출 전에 다시 확인합니다. 쓰기 결과가 미상일 수 있습니다.';

  @override
  String replaceFileReview(String path) {
    return '검토한 파일 $path을 바꿀까요? 대상이 바뀌면 새 검토가 필요합니다.';
  }

  @override
  String get diagramPngSaved => '다이어그램 PNG 저장됨. 긴 메모는 최대 여섯 줄 표시합니다.';

  @override
  String get editTargetChanged => '편집 대상이 바뀌었습니다. 준비 전에 행 편집기를 다시 여세요.';

  @override
  String affectedRowCount(String count) {
    return '영향을 받은 행: $count';
  }

  @override
  String get zoomIn => '확대';

  @override
  String get zoomOut => '축소';

  @override
  String get resetView => '보기 초기화';

  @override
  String get diagramKeys => '화살표로 이동하고 +와 -로 확대·축소하며 Home으로 보기를 초기화합니다.';

  @override
  String get explorerConnected => '탐색기 연결됨';

  @override
  String get explorerDisconnected => '탐색기 연결 해제됨';

  @override
  String querySessionCount(String count) {
    return '쿼리 세션 $count';
  }

  @override
  String get metadataColumn => '열';

  @override
  String get metadataPosition => '위치';

  @override
  String get metadataUnique => '고유';

  @override
  String get metadataJdbcType => 'JDBC 형식';

  @override
  String get metadataAutoIncrement => '자동 증가';

  @override
  String get metadataReferencedColumn => '참조된 열';

  @override
  String get metadataComment => '설명';

  @override
  String get metadataType => '형식';

  @override
  String get metadataEvent => '이벤트';

  @override
  String get metadataSpecificName => '기본 특정 식별자';

  @override
  String get metadataOptions => '옵션';

  @override
  String get metadataInheritance => '상속';

  @override
  String get metadataDefinitionCaptured => '캡처된 기본 정의';

  @override
  String get metadataDefinitionUnavailable => '캡처된 메타데이터에서 정의를 사용할 수 없음';

  @override
  String get metadataDefinitionUnsupported => '캡처된 개체에 지원되는 기본 정의가 없음';

  @override
  String get connections => '연결';

  @override
  String get noConnections => '아직 연결이 없습니다';

  @override
  String get startTitle => '데이터베이스에 연결';

  @override
  String get startDescription =>
      'PostgreSQL, MySQL 또는 MariaDB에 연결하여 객체를 탐색하고 데이터를 관리하며 쿼리를 실행하세요.';

  @override
  String get savedStartTitle => '연결 선택';

  @override
  String get savedStartDescription =>
      '데이터베이스 탐색기에서 저장된 연결에 연결하여 객체를 탐색하고 쿼리를 실행하세요.';

  @override
  String get noConnection => '연결 없음';

  @override
  String queryTitle(int number) {
    return '쿼리 $number';
  }

  @override
  String get sessionMenu => '세션';

  @override
  String get noFilterMatches => '일치하는 연결 또는 로드된 객체가 없습니다';

  @override
  String get activityState => '상태';

  @override
  String get activityWait => '대기';

  @override
  String get generalSettings => '일반';

  @override
  String get optionsSettings => '옵션';

  @override
  String get host => '호스트';

  @override
  String get databaseSystem => '데이터베이스 시스템';

  @override
  String get passwordStorage => '비밀번호 저장';

  @override
  String get environmentLabel => '환경';

  @override
  String get readOnlySettings => '읽기 전용 정책';

  @override
  String get tlsPolicy => 'TLS 정책';

  @override
  String get sshConnection => 'SSH 연결';

  @override
  String get sshAuthentication => 'SSH 인증';

  @override
  String get connectionTestAction => '연결 테스트';

  @override
  String get details => '세부 정보';

  @override
  String get copyDetails => '세부 정보 복사';

  @override
  String get retry => '다시 시도';

  @override
  String get filterCellValue => '이 값으로 필터링';

  @override
  String get connectsWhenRun => '실행 시 연결';

  @override
  String get connectionSaving => '저장…';

  @override
  String get connectionConnecting => '연결…';

  @override
  String get connectionCancelling => '취소…';

  @override
  String get connectionSettingsChanged => '설정이 변경되었습니다. 이 버전을 다시 테스트하세요.';

  @override
  String get connectionTestChanged => '설정이 변경되었습니다. 이 버전을 다시 테스트하세요.';

  @override
  String get connectionRequired => '필수';

  @override
  String get connectionCorrectFields => '표시된 설정을 확인하세요.';

  @override
  String get connectionHostname => '호스트 · 표시된 설정을 확인하세요.';

  @override
  String get connectionSshHostname => 'SSH · 호스트 · 표시된 설정을 확인하세요.';

  @override
  String get connectionMaxLength => '이름 ≤ 256';

  @override
  String get connectionTlsHelp => 'TLS · 호스트 · SSH/SSL. 표시된 설정을 확인하세요.';

  @override
  String get connectionTlsReview => 'TLS · 호스트 · SSH/SSL. 표시된 설정을 확인하세요.';

  @override
  String get connectionStorageUnavailable => '비밀번호 저장: 사용 불가. 비밀번호 · 저장 안 함.';

  @override
  String get connectionHostReviewed => '호스트 · 신뢰는 이 프로필과 정확한 접속 대상에만 적용됩니다.';

  @override
  String get connectionSshReviewing => 'SSH · SSH 호스트 키 검토…';

  @override
  String get connectionFailureAuthentication => '실패 · 인증 · 일반. 표시된 설정을 확인하세요.';

  @override
  String get connectionFailureTls => '실패 · TLS · SSH/SSL. 표시된 설정을 확인하세요.';

  @override
  String get connectionFailureSshKey => '실패 · SSH 호스트 키 검토. 표시된 설정을 확인하세요.';

  @override
  String get connectionFailureEndpoint => '실패 · 호스트 · 포트. 표시된 설정을 확인하세요.';

  @override
  String get connectionFailureCancelled => '취소됨';

  @override
  String get connectionFailureSettings => '실패 · 일반. 표시된 설정을 확인하세요.';

  @override
  String get connectionFailureAccess => '실패 · 테이블 / 뷰 권한. 표시된 설정을 확인하세요.';

  @override
  String get connectionFailureUnavailable =>
      '실패 · 호스트 · TLS · SSH. 표시된 설정을 확인하세요.';

  @override
  String get connectionFailureTimeout =>
      '실패 · 연결 시간 제한 · 1–120초. 표시된 설정을 확인하세요.';

  @override
  String get connectionFailureUnknown => '실패 · 일반 · TLS · SSH. 표시된 설정을 확인하세요.';

  @override
  String connectionNumber(int min, int max) {
    return '$min~$max 사이의 정수를 입력하세요';
  }

  @override
  String connectionSavedFailure(String name) {
    return '연결 저장됨: $name. 연결 시도가 실패했습니다. ';
  }

  @override
  String get backendBusy => '백엔드가 사용 중입니다. 현재 요청이 끝난 후 다시 시도하세요.';

  @override
  String rpcRequestUnconfirmed(String code) {
    return '요청이 확인되지 않았습니다(RPC $code).';
  }

  @override
  String get operationUnconfirmed => '작업을 완료할 수 없습니다.';

  @override
  String get connectionFailureTlsMaterial =>
      'TLS 자료를 사용할 수 없거나 유효하지 않습니다. SSH/SSL에서 신뢰 소스와 클라이언트 키를 확인하세요.';

  @override
  String get managerTitle => '데이터 소스 및 드라이버';

  @override
  String get sourceListTitle => '데이터 소스';

  @override
  String get driverLabel => '드라이버';

  @override
  String get connectionTypeLabel => '연결 유형';

  @override
  String get defaultTcp => '기본값 (TCP)';

  @override
  String get authenticationLabel => '인증';

  @override
  String get userPasswordAuth => '사용자 및 암호';

  @override
  String get neverStorage => '저장 안 함';

  @override
  String get initialDatabaseLabel => '초기 데이터베이스';

  @override
  String get useSshTunnel => 'SSH 터널 사용';

  @override
  String get sshConfigurationLabel => 'SSH 구성';

  @override
  String get createSshConfig => '<구성 만들기>';

  @override
  String get copySshSettings => 'SSH 설정 복사';

  @override
  String get localPortLabel => '로컬 포트';

  @override
  String get dynamicPortLabel => '<동적>';

  @override
  String get useSsl => 'SSL 사용';

  @override
  String get useTruststore => '신뢰 저장소 사용';

  @override
  String get clientKeyPasswordLabel => '클라이언트 키 암호';

  @override
  String get modeLabel => '모드';

  @override
  String get requireTls => '필수';

  @override
  String get verifyCa => 'CA 검증';

  @override
  String get fullVerification => '전체 검증';

  @override
  String get connectionSection => '연결';

  @override
  String get configurationApplied => '구성이 적용되었습니다';

  @override
  String get noOtherSshConfig => '다른 소스에 SSH 구성이 없습니다.';

  @override
  String get generatedUrlHelp => '생성된 읽기 전용 JDBC 주소입니다.';

  @override
  String get tlsDriverDefaultHelp => 'SSL이 구성되지 않았습니다. 번들 드라이버의 기본값을 사용합니다.';

  @override
  String get tlsClientKeyHelp => 'PEM 키: PKCS#8 또는 OpenSSL, 암호화 또는 비암호화.';

  @override
  String get legacyMariaTrustHelp =>
      '기존 드라이버 검증을 유지합니다. 명시적 루트를 구성하려면 신뢰 소스를 선택하세요.';

  @override
  String get metadataStartValue => '시작 값';

  @override
  String get metadataMinimumValue => '최솟값';

  @override
  String get metadataMaximumValue => '최댓값';

  @override
  String get metadataIncrement => '증가량';

  @override
  String get metadataCycle => '순환';

  @override
  String get metadataCacheSize => '캐시 크기';

  @override
  String get metadataLastValue => '마지막 값';

  @override
  String get sequences => '시퀀스';

  @override
  String get namespaceSelection => '네임스페이스 선택';

  @override
  String get namespaceSelectionNotice =>
      '선택은 메타데이터 검사를 제어합니다. 쿼리 콘솔의 실행 컨텍스트는 유지됩니다.';

  @override
  String get allNamespaces => '모든 네임스페이스';

  @override
  String get defaultNamespace => '기본값';

  @override
  String get namespacePattern => '이름 패턴 (정규 표현식)';

  @override
  String namespaceCount(int selected, int known) {
    return '$known 중 $selected';
  }

  @override
  String get previousPage => '이전 페이지';

  @override
  String get patternRejected => '패턴이 잘못되었거나 작업 제한을 초과했습니다. 이전 선택을 유지합니다.';

  @override
  String get namespaceNotSelected => '메타데이터 검사 대상으로 선택되지 않은 네임스페이스';

  @override
  String get newMenu => '새로 만들기';

  @override
  String get queryConsoles => '쿼리 콘솔';

  @override
  String get viewOptions => '보기 옵션';

  @override
  String get quickDocumentation => '빠른 문서';

  @override
  String get showEmptyGroups => '빈 그룹 표시';

  @override
  String get speedSearch => '빠른 검색';

  @override
  String get speedSearchScope => '펼쳐지고 로드된 노드만 검색합니다.';

  @override
  String get newSourceFolder => '새 데이터 소스 폴더';

  @override
  String get renameSourceFolder => '폴더 이름 변경';

  @override
  String get moveToFolder => '폴더로 이동';

  @override
  String get moveUp => '위로 이동';

  @override
  String get moveDown => '아래로 이동';

  @override
  String get folderMustBeEmpty => '폴더를 제거하기 전에 포함된 소스와 폴더를 이동하세요.';

  @override
  String get newVirtualView => '새 가상 뷰';

  @override
  String get editVirtualDefinition => '로컬 정의 편집';

  @override
  String get unboundVirtualView => '연결되지 않은 가상 뷰';

  @override
  String get localVirtualViewNotice =>
      '로컬 SQL 정의입니다. 저장은 SQL을 실행하거나 서버 뷰를 만들지 않습니다. 실행에는 일반 SQL 검토와 독립 콘솔을 사용합니다.';

  @override
  String get rebindVirtualView => '로컬 정의를 여기에 연결';

  @override
  String get sourceFolderName => '폴더 이름';

  @override
  String get sourceFolderPathNotice => '/로 중첩 폴더를 만듭니다.';

  @override
  String get topLevel => '최상위';

  @override
  String get virtualViewName => '가상 뷰 이름';

  @override
  String get virtualViewSql => '가상 뷰 SQL 정의';

  @override
  String get virtualViews => '가상 뷰';

  @override
  String get revealInExplorer => '데이터베이스 탐색기에 표시';

  @override
  String get objectNotFound =>
      '이 네임스페이스에서 개체를 찾지 못했습니다. 메타데이터를 새로 고치거나 권한을 확인하세요.';

  @override
  String get objectHiddenByFilter => '현재 보기 필터가 개체를 숨깁니다.';

  @override
  String get revealFilterNotice => '개체 검색으로 이 페이지가 제한되어 전체 범주 개수는 생략됩니다.';

  @override
  String get clearObjectFilter => '개체 검색 해제';

  @override
  String get compareStructure => '구조 비교';

  @override
  String get selectTwoCompatibleObjects => 'Ctrl 클릭으로 호환되는 테이블 두 개를 선택하세요.';

  @override
  String get scopedComparisonRestriction =>
      '비교하려면 기본 이름, 스키마, 엔진이 같은 일반 테이블이 필요합니다. 다른 종류와 이름 변경 일치는 지원하지 않습니다.';

  @override
  String get groupNamespaces => '데이터베이스와 스키마 그룹화';

  @override
  String get groupSchemaObjects => '스키마 개체 그룹화';

  @override
  String get groupTableElements => '테이블 요소 그룹화';

  @override
  String get sortAlphabetically => '이름순 정렬';

  @override
  String get showVirtualObjects => '가상 개체 표시';

  @override
  String get showObjectComments => '개체 설명 표시';

  @override
  String get objectTypeFilter => '개체 종류 필터';

  @override
  String get partitionedTable => '분할 테이블';

  @override
  String get foreignTable => '외부 테이블';

  @override
  String get materializedView => '구체화된 뷰';

  @override
  String get functionObject => '함수';

  @override
  String get procedureObject => '프로시저';

  @override
  String get sqlSymbolUnavailable =>
      '커서 위치에서 영구 개체를 안전하게 확인하지 못했습니다. 이 콘솔을 연결하고 리터럴과 주석 밖의 테이블 또는 뷰 참조를 사용하세요.';

  @override
  String get sqlSymbolAmbiguous =>
      'SQL 개체 참조가 모호합니다. 네임스페이스를 지정하거나 정확한 데이터베이스 개체를 선택하세요.';

  @override
  String get deactivateSource => '데이터 소스 비활성화';

  @override
  String get functions => '함수';

  @override
  String get procedures => '프로시저';

  @override
  String get separateProceduresFunctions => '프로시저와 함수 분리';

  @override
  String get renameVirtualView => '가상 뷰 이름 바꾸기';

  @override
  String get metadataPersistentScope =>
      '영구 객체만 표시합니다. 임시 객체와 세션 로컬 객체는 콘솔 탐색에 남습니다.';

  @override
  String get metadataSessionScope => '영구 객체만 표시합니다. 실행 후 콘솔 로컬 객체를 새로 고치세요.';

  @override
  String get metadataLimitScope => '메타데이터 한도에 도달했습니다. 객체 범위를 좁히세요.';

  @override
  String get completeColumnMetadataRequired =>
      '가져오기 또는 변경 사항 준비 전에 전체 열 메타데이터가 필요합니다.';

  @override
  String resizeColumn(String name) {
    return '열 $name 너비 조정';
  }

  @override
  String get keyboardShortcutsHeading => '키보드 단축키';

  @override
  String sqlEditorLabel(String title) {
    return 'SQL 편집기 $title';
  }

  @override
  String get editorResultsDivider => '편집기와 결과 구분선';

  @override
  String editorExtent(String percent) {
    return '편집기 $percent퍼센트';
  }

  @override
  String get largerEditor => '편집기 확대';

  @override
  String get smallerEditor => '편집기 축소';

  @override
  String get explorerWidthDivider => '탐색기 너비 구분선';

  @override
  String get widerExplorer => '탐색기 넓히기';

  @override
  String get narrowerExplorer => '탐색기 좁히기';

  @override
  String explorerExtent(String width) {
    return '너비 $width픽셀';
  }

  @override
  String planTextPage(String start, String end, String total) {
    return '전체 $total UTF-16 단위 중 $start–$end';
  }

  @override
  String get dropDesignedColumn => '열 삭제';

  @override
  String get liveCatalogLabel => '현재 카탈로그';

  @override
  String get liveSchemaLabel => '현재 스키마';

  @override
  String get searchPathLabel => '검색 경로';

  @override
  String get physicalSessionLabel => '물리 세션';

  @override
  String queryTimeoutDetail(String seconds, String rows) {
    return '시간 제한: $seconds초 · 행 제한: $rows';
  }

  @override
  String get saveFailedCloseTitle => 'SQL 저장 실패 · BusyData 닫기';

  @override
  String get createSection => '만들기';

  @override
  String get newConnectionDescription => '데이터베이스 연결 설정';

  @override
  String get newQueryDescription => '새 쿼리에서 SQL 작성';

  @override
  String get openSqlDescription => '기존 SQL 문서 열기';

  @override
  String get searchNoResults => '일치하는 작업 없음';

  @override
  String get actionsCategory => '작업';

  @override
  String get privateRecoveryCategory => '비공개 복구';

  @override
  String get shortcutRecordHelp =>
      '단축키를 누르세요. Escape로 취소합니다. F6 및 Shift+F6은 창 영역 탐색용입니다.';

  @override
  String get rowLimitInvalid => '행 제한을 1~1,000,000 사이로 입력하세요.';

  @override
  String get errorPolicy => '실행 오류 발생 시';

  @override
  String get tlsEncrypted => '암호화됨';

  @override
  String get tlsUnencrypted => '암호화되지 않음';

  @override
  String get tlsUnobserved => '관찰되지 않음';

  @override
  String get encryptionVerificationNote => '암호화가 인증서 또는 호스트 이름 검증을 보장하지는 않습니다.';

  @override
  String get uniqueDesignedColumnName =>
      '고유한 열 이름을 사용하세요. 새 테이블은 최대 128개 열을 지원합니다';

  @override
  String activityBlockerUnavailable(String id) {
    return '차단 세션 $id이 더 이상 보이지 않습니다. 새로 고침하고 데이터베이스 권한을 확인하세요';
  }

  @override
  String get sshChangedKeyReview => '프로필 연결을 바꾸기 전에 변경된 키를 별도로 검증하세요.';

  @override
  String get sshProfileTrustBinding => '신뢰는 이 프로필과 정확한 접속 대상에만 적용됩니다.';

  @override
  String get databaseTlsEvidence => 'TLS · 데이터베이스 시스템';

  @override
  String get sshAlgorithmLabel => 'SSH · 형식';

  @override
  String get sshFingerprintLabel => 'SHA-256';

  @override
  String get sshPreviousFingerprintLabel => '이전 · SHA-256';

  @override
  String get sshReviewedLabel => 'SSH 호스트 키 검토';

  @override
  String get shortcutRecordAction => '단축키 기록';

  @override
  String get fileFormatLabel => '파일 형식';

  @override
  String get encodingLabel => '인코딩';

  @override
  String get importPolicyLabel => '가져오기 정책';

  @override
  String get mainMenu => '메인 메뉴';

  @override
  String get activityReplyTooLarge => '활동 응답이 검사기 한도를 초과합니다.';

  @override
  String get activityListLimited => '목록이 제한되었습니다. 명시적 SQL로 더 좁은 대상을 검사하세요.';

  @override
  String get activitySelectionChanged =>
      '선택한 활동이 종료되었거나 변경되었습니다. 작업을 검토하기 전에 현재 식별 정보를 선택하세요.';

  @override
  String connectionSavedDraftChanged(String name) {
    return '저장 중 연결 필드가 변경되었습니다. 구성은 저장되었습니다: $name. 연결하기 전에 현재 값을 검토하세요.';
  }

  @override
  String get sshReviewTargetChanged => 'SSH 검토 대상이 변경되었습니다. 다시 검토하세요';

  @override
  String get appearance => '화면 모양';

  @override
  String get theme => '테마';

  @override
  String get systemTheme => '시스템';

  @override
  String get lightTheme => '밝게';

  @override
  String get darkTheme => '어둡게';

  @override
  String get appLanguage => '언어';

  @override
  String get systemLanguage => '시스템 언어';

  @override
  String get cut => '잘라내기';

  @override
  String get paste => '붙여넣기';

  @override
  String get selectAll => '모두 선택';

  @override
  String get noSelection => '사용 가능한 텍스트가 없습니다';

  @override
  String get clipboardEmpty => '클립보드에 텍스트가 없습니다';

  @override
  String get settingsDraftNotice => '실행 및 비공개 복구 변경 사항이 저장되지 않았습니다.';

  @override
  String get documentsMenu => '문서';

  @override
  String get currentSql => '현재 SQL';

  @override
  String get searchActionsHint => '작업 검색…';

  @override
  String get searchCurrentSqlHint => 'Search current SQL…';

  @override
  String get searchObjectsHint => 'Search database objects…';

  @override
  String get searchHistoryHint => 'Search query history…';

  @override
  String get metadataAttributes => '속성';

  @override
  String get metadataSelectionUnavailable =>
      '캡처된 속성을 확인할 항목을 선택하세요. 이전 선택은 사용할 수 없습니다.';

  @override
  String get secureStorage => 'OS 보안 저장소';

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
      '캐시를 저장하지 못했습니다. 현재 메타데이터는 계속 사용할 수 있습니다.';

  @override
  String get metadataCacheRebuiltVersion => '현재 버전에 맞게 다시 생성됨';

  @override
  String get metadataCacheRebuiltCorrupt => '캐시 오류 후 다시 생성됨';

  @override
  String get editSessionBusy =>
      '이 세션은 사용 중입니다. 현재 작업이 완료될 때까지 기다린 후 편집 가능 여부를 다시 평가해 달라고 요청하세요.';

  @override
  String get editIdentityRequired =>
      '편집하기 전에 기본 키 또는 NULL을 허용하지 않는 고유 키의 모든 열을 선택하세요.';

  @override
  String get editColumnsReadOnly => '결과에 선택된 모든 열이 생성된 열이거나 읽기 전용입니다.';

  @override
  String get editResultNotReady =>
      '보존된 이 결과가 완료될 때까지 기다린 후 편집 가능 여부를 다시 평가해 달라고 요청하세요.';

  @override
  String get editProjectionUnsupported =>
      '편집하려면 하나의 기본 테이블에서 각 기본 열을 한 번씩만 선택하는 직접 SELECT가 필요합니다.';

  @override
  String get sqlInspectionDuplicateUsingColumn => '중복된 JOIN USING 열';

  @override
  String get sqlInspectionUnresolvedUsingColumn => '한 피연산자에 JOIN USING 열이 없음';

  @override
  String get sqlInspectionAmbiguousUsingColumn => '모호한 JOIN 공통 열';

  @override
  String get sqlInspectionOutputColumnCount => '선언된 출력 열 수 불일치';

  @override
  String get sqlInspectionAmbiguousOverload => '모호한 루틴 오버로드';

  @override
  String get sqlInspectionBooleanType => '잘못된 부울 표현식 형식';

  @override
  String get sqlInspectionOperatorTypes => '호환되지 않는 연산자 피연산자 형식';

  @override
  String get sqlInspectionArrayTypes => '호환되지 않는 배열 요소 형식';

  @override
  String get sqlInspectionCaseConditionType => '호환되지 않는 CASE 조건 형식';

  @override
  String get sqlInspectionCaseResultTypes => '호환되지 않는 CASE 결과 형식';

  @override
  String get sqlInspectionCoalesceTypes => '호환되지 않는 COALESCE 인수 형식';

  @override
  String get sqlInspectionSetColumnCount => '집합 연산의 열 수 불일치';

  @override
  String get sqlInspectionSetTypes => '호환되지 않는 집합 연산 결과 형식';

  @override
  String get sqlInspectionRecursiveCteType => '재귀 CTE 형식 불일치';
}
