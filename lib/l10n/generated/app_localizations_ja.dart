// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get cancel => 'キャンセル';

  @override
  String get windowMinimize => '最小化';

  @override
  String get windowMaximize => '最大化';

  @override
  String get windowRestore => '元に戻す';

  @override
  String get databaseExplorer => 'データベースエクスプローラー';

  @override
  String get databases => 'データベース';

  @override
  String get newConnection => '新しい接続';

  @override
  String get filterTree => '接続とオブジェクトを絞り込む';

  @override
  String get treeFilterScope => '読み込み済みのツリー内オブジェクトを絞り込みます';

  @override
  String get searchObjects => 'データベースオブジェクトを検索';

  @override
  String get fileMenu => 'ファイル';

  @override
  String get editMenu => '編集';

  @override
  String get viewMenu => '表示';

  @override
  String get connectionMenu => '接続';

  @override
  String get objectMenu => 'オブジェクト';

  @override
  String get runMenu => '実行オプション';

  @override
  String get commands => 'コマンド';

  @override
  String get findCommand => 'コマンドを検索';

  @override
  String get newSql => '新しいクエリ';

  @override
  String get openSql => 'SQL を開く';

  @override
  String get openSqlFile => 'SQLファイルを開く';

  @override
  String get saveSql => 'SQL を保存';

  @override
  String get closeTab => 'タブを閉じる';

  @override
  String get openWorkspace => 'ワークスペースを開く';

  @override
  String get saveWorkspace => 'ワークスペースを保存';

  @override
  String get settings => '設定';

  @override
  String get findText => '検索';

  @override
  String get replaceText => '置換';

  @override
  String get formatSql => 'SQL を整形';

  @override
  String get lineComments => '行コメントを切り替える';

  @override
  String get snippets => 'SQL スニペット';

  @override
  String get run => '実行';

  @override
  String get runStatement => '現在の文を実行';

  @override
  String get runSelection => '選択範囲を実行';

  @override
  String get runScript => 'スクリプトを実行';

  @override
  String get explain => '実行計画';

  @override
  String get explainAnalyze => '実行して計画を取得';

  @override
  String get connect => '接続';

  @override
  String get disconnect => '切断';

  @override
  String get sessionDetails => 'セッションの詳細';

  @override
  String get beginTransaction => 'トランザクションを開始';

  @override
  String get commitTransaction => 'トランザクションをコミット';

  @override
  String get rollbackTransaction => 'トランザクションをロールバック';

  @override
  String get enableAutoCommit => '自動コミットを有効にする';

  @override
  String get disableAutoCommit => '自動コミットを無効にする';

  @override
  String get outcomeUnknown => '結果不明';

  @override
  String get outcomeUnknownNote =>
      '操作は完了している可能性があります。このセッションではこれ以上 SQL を実行できません。自動的に再試行せず、新しい作業を始める前に結果を確認してください。';

  @override
  String get notConnected => '切断済み';

  @override
  String get autoCommit => '自動コミット';

  @override
  String get manualTransaction => '手動トランザクション';

  @override
  String get readOnlyPolicy => 'BusyData の読み取り専用ポリシー';

  @override
  String get data => 'データ';

  @override
  String get structure => '構造';

  @override
  String get results => '結果';

  @override
  String get messages => 'メッセージ';

  @override
  String get plan => '計画';

  @override
  String get changes => '変更';

  @override
  String get history => '履歴';

  @override
  String get jobs => 'ジョブ';

  @override
  String get retainedResults => '保持された結果';

  @override
  String get recoverEdits => '準備した変更を復元';

  @override
  String get applyAndCommit => '適用してコミット';

  @override
  String get inspectStructure => '構造を調べる';

  @override
  String get openData => 'データを開く';

  @override
  String get openDefinition => '定義を開く';

  @override
  String get copyQualifiedName => '修飾名をコピー';

  @override
  String get refresh => '更新';

  @override
  String get columns => '列';

  @override
  String get indexes => 'インデックス';

  @override
  String get constraints => 'キーと制約';

  @override
  String get foreignKeys => '外部キー';

  @override
  String get triggers => 'トリガー';

  @override
  String get definition => '定義';

  @override
  String get dependencies => '依存関係';

  @override
  String get connectionCapabilities => '接続の概要';

  @override
  String get sessionsAndLocks => 'セッションとロック';

  @override
  String get usersAndRoles => 'ユーザーとロール';

  @override
  String get saveSnapshot => 'スキーマのスナップショットを保存';

  @override
  String get compareSchemas => 'スキーマを比較';

  @override
  String get objectDesigner => 'オブジェクトデザイナー';

  @override
  String get diagram => 'ER 図';

  @override
  String get backup => 'バックアップ';

  @override
  String get restore => '復元';

  @override
  String get importData => 'データをインポート';

  @override
  String get exportRetained => '保持されたデータをエクスポート';

  @override
  String get exportSql => 'SQL エクスポートを実行';

  @override
  String get stageInsert => '行を挿入';

  @override
  String get stageUpdate => '行を編集';

  @override
  String get stageDelete => '行を削除';

  @override
  String get discardChanges => '保留中の変更を破棄';

  @override
  String get disposeResult => '保持されたデータを解放';

  @override
  String get currentSchema => '現在のスキーマ（変更対象）';

  @override
  String get desiredSchema => '目的のスキーマ';

  @override
  String get applyTo => '適用先';

  @override
  String get loading => '読み込み中';

  @override
  String get empty => 'この範囲にはオブジェクトがありません';

  @override
  String get more => 'その他';

  @override
  String get filter => '絞り込み';

  @override
  String get sort => '並べ替え';

  @override
  String get selectTarget => '接続を選択';

  @override
  String get requireSql => 'SQL ドキュメントが必要です';

  @override
  String get requireSession => '接続済みで状態が確認されたセッションが必要です';

  @override
  String get requireResult => '保持されたデータが必要です';

  @override
  String get requireObject => '対象オブジェクトが必要です';

  @override
  String get cancelRequested => 'キャンセルを要求済み';

  @override
  String get cancelled => 'キャンセル済み';

  @override
  String get queued => '待機中';

  @override
  String get running => '実行中';

  @override
  String get completed => '完了';

  @override
  String get failed => '失敗';

  @override
  String get partial => '一部のみ';

  @override
  String get sessionSharing => '既存のセッションを共有（詳細設定）';

  @override
  String get production => '本番';

  @override
  String get staging => 'ステージング';

  @override
  String get development => '開発';

  @override
  String get executionOptions => '実行オプション';

  @override
  String get resultRowLimit => '結果の行数制限（1–1000000）';

  @override
  String get boundedRead => '制限付き読み取り';

  @override
  String get streamingRead => 'ストリーミング読み取り · 読み取りトランザクションを保持';

  @override
  String get stopOnError => 'エラー時にスクリプトを停止';

  @override
  String get continueOnError => 'エラー時も続行 · 先行する文はコミット済みの可能性があります';

  @override
  String get loadMore => 'さらに読み込む';

  @override
  String get favorite => 'お気に入りを切り替える';

  @override
  String get connectionGroup => '接続グループ';

  @override
  String get copyRange => '範囲をコピー';

  @override
  String get inspectValue => '値を調べる';

  @override
  String get editConnection => '接続を編集';

  @override
  String get chooseSnapshot => 'スナップショットを選択';

  @override
  String get captureSchema => 'スキーマを取得';

  @override
  String get sameSchemaRestriction =>
      'スナップショットのエンジン、スキーマ名、バージョンは同一でなければなりません。比較や保存によって変更が適用されることはありません。';

  @override
  String get restoredTaskState =>
      'ドキュメントの参照を復元しました。以前のバックエンドのデータ、セッション、ジョブは利用できません。明示的な操作で新しい作業を開始してください。復元は接続、SQL の実行、変更の再適用を行いません。';

  @override
  String get preChangeSnapshot =>
      '変更前のスナップショット · 変更はコミット済みです。現在の行とサーバーの既定値を調べるには明示的に更新してください。';

  @override
  String get sqlProvenance => 'SQL の由来';

  @override
  String get assessEditing => '編集可否を確認';

  @override
  String get viewDetails => '詳細を表示';

  @override
  String get gridMenu => 'データグリッド';

  @override
  String get visibleColumns => '表示する列';

  @override
  String get hidden => '非表示';

  @override
  String get ascending => '昇順';

  @override
  String get descending => '降順';

  @override
  String get equals => '等しい';

  @override
  String get notEqual => '等しくない';

  @override
  String get lessThan => 'より小さい';

  @override
  String get greaterThan => 'より大きい';

  @override
  String get isNull => 'NULL である';

  @override
  String get isNotNull => 'NULL でない';

  @override
  String get exactValue => '正確な値';

  @override
  String get sortTable => 'テーブルデータを並べ替え';

  @override
  String get filterTable => 'テーブルデータを絞り込み';

  @override
  String get sortRetained => '保持したスナップショットを並べ替え';

  @override
  String get filterRetained => '保持したスナップショットを絞り込み';

  @override
  String get applyView => '適用';

  @override
  String get rowsLabel => '行';

  @override
  String get fetchedRows => '取得済みの行';

  @override
  String get fixedSnapshot => '取得済みの行の固定スナップショット';

  @override
  String get limitReached => '上限に到達';

  @override
  String get retainedData => '保持したデータ';

  @override
  String get applyRequiresAutoCommit =>
      '適用してコミットするには、アイドル状態で自動コミットが有効なセッションが必要です。';

  @override
  String get connectionProfile => '接続プロファイル';

  @override
  String get basic => '基本';

  @override
  String get advanced => '詳細';

  @override
  String get connectionName => '名前';

  @override
  String get hostname => 'ホスト名（TLS 検証にも使用）';

  @override
  String get port => 'ポート';

  @override
  String get database => 'データベース';

  @override
  String get user => 'ユーザー';

  @override
  String get password => 'パスワード';

  @override
  String get writableProfile => '書き込み可能なプロファイル';

  @override
  String get readonlyProfile => '読み取り専用プロファイル';

  @override
  String get tlsVerify => 'TLS: 証明書とホスト名を検証';

  @override
  String get tlsInsecure => 'TLS: 安全ではありません、検証しない';

  @override
  String get tlsDisabled => 'TLS: 無効';

  @override
  String get testConnection => '保存せずにテスト';

  @override
  String get saveProfile => '保存';

  @override
  String get saveConnect => '保存して接続';

  @override
  String get sessionPassword => 'このセッションのみのパスワード';

  @override
  String get storedPassword => 'OS の安全な領域にパスワードを保存';

  @override
  String get chooseFile => 'ファイルを選択';

  @override
  String get testRunning => '接続をテスト中…';

  @override
  String get cancelTest => 'テストをキャンセル';

  @override
  String get idle => '待機中';

  @override
  String get activeTransaction => 'トランザクション実行中';

  @override
  String get failedTransaction => 'トランザクション失敗';

  @override
  String get inspectionContext => '検査セッション';

  @override
  String get requireTableOrView => 'テーブルまたはビューを選択';

  @override
  String get operationPending => 'ドキュメントの操作は確認応答を待っています';

  @override
  String get requirePlan => '保持された Explain 実行を選択';

  @override
  String get openPlanDocument => 'プランドキュメントを開く';

  @override
  String get locks => 'ロック';

  @override
  String get statistics => '統計';

  @override
  String get queryStatistics => 'クエリ統計';

  @override
  String get indexDiagnostics => 'インデックス診断';

  @override
  String get grants => '付与された権限';

  @override
  String get sqlExecution => 'SQL 実行';

  @override
  String get planReady => '保持されたプランの準備ができました。SQL は再実行されていません';

  @override
  String get executionPlan => '実行プラン';

  @override
  String get openOwner => '所有元を開く';

  @override
  String get terminateActivity => 'アクティビティを終了';

  @override
  String get close => '閉じる';

  @override
  String get previous => '前へ';

  @override
  String get next => '次へ';

  @override
  String get replaceSelection => '選択範囲を置換';

  @override
  String get replaceAll => 'すべて置換';

  @override
  String get restartBackend => 'バックエンドを再起動';

  @override
  String get structuredTree => '構造ツリー';

  @override
  String get rawOutput => '生の出力';

  @override
  String get previousTextPage => '前のテキストページ';

  @override
  String get nextTextPage => '次のテキストページ';

  @override
  String get filterChangedObjects => '変更されたオブジェクトを絞り込む';

  @override
  String get rebindVerifiedEdits => '検証済み編集を再関連付け';

  @override
  String get discardRecoveryRecord => '復旧レコードを破棄';

  @override
  String get revertChange => '保留中の変更を元に戻す';

  @override
  String get chooseSource => 'ソースを選択';

  @override
  String get chooseDestination => '保存先を選択';

  @override
  String get delimiterField => '区切り文字（1文字）';

  @override
  String get batchRowsField => 'バッチあたりの行数（1–1000）';

  @override
  String get rejectedLimit => '拒否行数の上限（1–1000）';

  @override
  String get previewSource => 'ソースをプレビュー';

  @override
  String get reviewTransfer => '転送をレビュー';

  @override
  String get startImport => 'インポート開始';

  @override
  String get startRestore => '復元開始';

  @override
  String get startExport => 'エクスポート開始';

  @override
  String get requestCancel => 'キャンセルを要求';

  @override
  String get sourceMapping => 'ソースとターゲットの対応';

  @override
  String get nativeTool => 'ネイティブツール';

  @override
  String get defaultOmit => '省略 / データベースの既定値';

  @override
  String get overwriteNever => '上書きしない';

  @override
  String get overwriteExisting => '既存ファイルを上書き';

  @override
  String get planDetails => 'プランの詳細';

  @override
  String get planMetricsNote => '推定値と実測値はサーバーのフィールド名を使用します。欠けている測定値は利用できません。';

  @override
  String get connected => '接続済み';

  @override
  String get disconnected => '切断済み';

  @override
  String get tables => 'テーブル';

  @override
  String get views => 'ビュー';

  @override
  String get routines => 'ルーチン';

  @override
  String get expand => '展開';

  @override
  String get collapse => '折りたたむ';

  @override
  String get databaseWorkbench => 'データベースワークベンチ';

  @override
  String get sidebar => 'サイドバー';

  @override
  String get unchanged => '変更なし';

  @override
  String get reviewDetails => 'レビューの詳細';

  @override
  String get generatedSql => '生成されたSQL';

  @override
  String get changeReverted => '保留中の変更を戻しました。新しいレビューを要求してください。';

  @override
  String get unknownBatch =>
      '結果は不明です。バッチがコミット済みの可能性があります。自動再実行せず、セッションと復旧レコードを照合してください。';

  @override
  String get expiredChangeReview => '対象が変更されたかレビューの期限が切れました。新しいレビューを要求してください。';

  @override
  String get applyCommitExplanation =>
      '適用してコミットは独自のトランザクションを開始してコミットします。元のコンソールはアイドル状態で自動コミットが有効である必要があります。手動SQLトランザクションは別に解決してください。';

  @override
  String get newRow => '新しい行';

  @override
  String get original => '元の値';

  @override
  String get proposed => '提案値';

  @override
  String changeCounts(int inserts, int updates, int deletes) {
    return '挿入 $inserts · 更新 $updates · 削除 $deletes';
  }

  @override
  String sourceRow(String row) {
    return '元の行 $row';
  }

  @override
  String get refreshing => '更新中…';

  @override
  String get refreshActivities => 'アクティビティを更新';

  @override
  String get explicitRefresh => '明示的に更新';

  @override
  String get pollFiveSeconds => '5秒ごとに確認';

  @override
  String get cancelSelectedActivity => '選択したアクティビティをキャンセル';

  @override
  String get terminateSelectedSession => '選択したセッションを終了';

  @override
  String get filterActivities => '現在のアクティビティを絞り込む';

  @override
  String get blockedBy => 'ブロック元:';

  @override
  String get delete => '削除';

  @override
  String get remove => '削除';

  @override
  String get up => '上へ';

  @override
  String get search => '検索';

  @override
  String get yes => 'はい';

  @override
  String get no => 'いいえ';

  @override
  String get clear => '消去';

  @override
  String get copy => 'コピー';

  @override
  String get insert => '挿入';

  @override
  String get update => 'アップデート';

  @override
  String get open => '開く';

  @override
  String get migrationEngineMismatch =>
      '適用先の接続は比較したスナップショットと同じエンジンを使用する必要があります。異なるエンジン間の移行は未対応です。';

  @override
  String get metadataContextChanged => '検査コンテキストが変更されました。メタデータを明示的に更新してください。';

  @override
  String get newTableName => '新しいテーブル名';

  @override
  String get routineIdentity => 'ルーチンの正確な識別子';

  @override
  String get objectColumnName => 'オブジェクト / 列名';

  @override
  String get builtInType => '組み込み型';

  @override
  String get sqlExpression => 'SQL 式（空欄で削除）';

  @override
  String get newPropertyValue => '新しいプロパティ値';

  @override
  String get columnComment => '列コメント';

  @override
  String get columnCollation => '列の照合順序（空欄でサーバー既定値）';

  @override
  String get addDesignedColumn => '新しいテーブルに列を追加';

  @override
  String get checkExpression => 'CHECK 式';

  @override
  String get referencedSchema => '参照先スキーマ / データベース';

  @override
  String get generating => '生成中…';

  @override
  String get generateReviewedDdl => 'レビュー用 DDL を生成';

  @override
  String get inspectCapturedDefinition => '取得済みの定義を確認';

  @override
  String get capturedObject => '取得済みオブジェクト';

  @override
  String get designReviewNote =>
      '変更はレビュー用に生成されます。レビュー済みの実行までデータベースの内容は変更されません。';

  @override
  String get columnMetadataUnavailable =>
      'この範囲の列メタデータは利用できません。列リストを設計する前に選択したスキーマを確認してください。';

  @override
  String get ordinaryColumn => '通常の列';

  @override
  String get columnWithDefault => '既定値付きの列';

  @override
  String get identityColumn => 'IDENTITY / 自動増分';

  @override
  String get generatedColumn => '生成列';

  @override
  String get columnType => '列の型';

  @override
  String get nullableNotNull => 'NULL 許可 / NOT NULL';

  @override
  String get defaultExpression => '既定値の式';

  @override
  String get generatedExpression => '生成式';

  @override
  String get columnCollationProperty => '列の照合順序';

  @override
  String get loggedUnlogged => 'ログあり / ログなし';

  @override
  String get tableComment => 'テーブルのコメント';

  @override
  String get storageEngine => 'ストレージエンジン';

  @override
  String get tableCollation => 'テーブルの照合順序';

  @override
  String get rowFormat => '行の形式';

  @override
  String get createOrReplace => '作成または置換';

  @override
  String get dropSelectedObject => '選択したオブジェクトを削除';

  @override
  String get addColumn => '列を追加';

  @override
  String get editColumnProperties => '列のプロパティを編集';

  @override
  String get tableProperties => 'テーブルのプロパティ';

  @override
  String get triggerDefinition => 'トリガーの定義';

  @override
  String get createTable => 'テーブルを作成';

  @override
  String get viewDefinition => 'ビューの定義';

  @override
  String get routineDefinition => 'ルーチンの定義';

  @override
  String get chooseExistingObject => '既存のオブジェクトを選択';

  @override
  String get nullable => 'NULL を許可';

  @override
  String get removeIdentity => 'IDENTITY を削除';

  @override
  String get generatedAlways => '常に生成';

  @override
  String get generatedByDefault => '既定で生成 / 自動増分';

  @override
  String get loggedTable => 'ログありテーブル';

  @override
  String get unloggedTable => 'ログなしテーブル';

  @override
  String get orderedPrimaryKeyColumns => '順序付き主キー列';

  @override
  String get orderedColumns => '順序付き列';

  @override
  String get ordinaryIndex => '通常のインデックス';

  @override
  String get uniqueIndex => '一意のインデックス';

  @override
  String get primaryKey => '主キー';

  @override
  String get uniqueConstraint => '一意制約';

  @override
  String get foreignKey => '外部キー';

  @override
  String get checkConstraint => 'CHECK 制約';

  @override
  String get immediateChecking => '即時チェック';

  @override
  String get deferrableChecking => '延期可能なチェック';

  @override
  String get initiallyImmediate => '初期は即時';

  @override
  String get initiallyDeferred => '初期は延期';

  @override
  String get referencedTable => '参照先テーブル';

  @override
  String get orderedReferencedColumns => '対応する順序の参照先列';

  @override
  String get objectDefinitionEditor => 'ネイティブオブジェクト定義の SQL エディター';

  @override
  String get onDelete => '削除時';

  @override
  String get onUpdate => '更新時';

  @override
  String get stay => '留まる';

  @override
  String get saveSqlClose => 'SQL を保存して閉じる';

  @override
  String get discardSqlClose => 'SQL を破棄して閉じる';

  @override
  String get closeBusyData => 'BusyData を閉じる';

  @override
  String get saveDraftsClose => '下書きを保存して閉じる';

  @override
  String get closeWithoutRecovery => '復元せずに閉じる';

  @override
  String get recoveryFailed => '復元に失敗';

  @override
  String get discardFailedSaveClose => '失敗した保存を破棄して閉じる';

  @override
  String get closeWithoutSavingRecovery => '復元データを保存せずに閉じる';

  @override
  String get disableSqlRecovery => 'SQL 復元を無効化';

  @override
  String get historyPrivacy => '履歴のプライバシー';

  @override
  String get enableSqlRetention => 'SQL 保持を有効化';

  @override
  String get disableSqlRetention => 'SQL 保持を無効化';

  @override
  String get clearHistory => '履歴を消去';

  @override
  String get deleteHistoryEntry => '履歴の項目を削除';

  @override
  String get deleteSelected => '選択項目を削除';

  @override
  String get saveRetention => '保持設定を保存';

  @override
  String get retentionDays => '保持日数';

  @override
  String get sqlTextRetained => 'SQL テキストを保持';

  @override
  String get sqlTextDisabled => 'SQL テキスト無効';

  @override
  String get openHistoryQuery => '新しい SQL タブで開く';

  @override
  String get caCertificateFile => 'CA 証明書ファイル';

  @override
  String get clientCertificateFile => 'クライアント証明書ファイル';

  @override
  String get clientKeyFile => 'クライアント鍵ファイル';

  @override
  String get directConnection => '直接接続';

  @override
  String get sshTunnel => 'SSH トンネル';

  @override
  String get sshHost => 'SSH ホスト';

  @override
  String get sshPort => 'SSH ポート';

  @override
  String get sshUser => 'SSH ユーザー';

  @override
  String get reviewedKnownHosts => '確認済み known_hosts ファイル';

  @override
  String get reviewSshKey => 'SSH ホスト鍵を確認';

  @override
  String get changedSshKey => 'SSH ホスト鍵が変更';

  @override
  String get verifyFingerprint => '信頼する前に、このフィンガープリントを独立して確認してください。';

  @override
  String get selectedKeyPassword => '選択した鍵またはパスワード';

  @override
  String get selectedAgentIdentity => '選択した SSH エージェント ID';

  @override
  String get selectedAgentSocket => '選択した Linux エージェントソケット / Windows 名前付きパイプ';

  @override
  String get selectedKeyFingerprint => '選択した鍵のフィンガープリント · SHA256:…';

  @override
  String get selectedPrivateKey => '選択した秘密鍵（任意）';

  @override
  String get sshPassword => 'SSH パスワード';

  @override
  String get keyPassphrase => '鍵のパスフレーズ';

  @override
  String get connectionTimeout => '接続タイムアウト · 1–120 秒';

  @override
  String get sqlTimeout => 'SQL 実行/取得期限 · 1–3600 秒（0 = 60）';

  @override
  String get schemasEquivalent => '取得したスキーマは同等です。';

  @override
  String get migrationComplete => '移行は対応する取得済み差分を網羅します。';

  @override
  String get migrationPartial => '部分的な移行です。未対応の差分が残っています。';

  @override
  String get differencesLimited =>
      '差分の表示は制限されています。保存した完全なスナップショットと生成 SQL を確認してください。';

  @override
  String get absent => 'なし';

  @override
  String get definitionPreviewLimited =>
      '定義のプレビューは制限されています。完全な根拠には元のスナップショットを使用してください。';

  @override
  String get migrationBatchNote =>
      'SQL は依存関係順の単一バッチです。個別のオブジェクト選択は確認用で、適用する文の選択ではありません。';

  @override
  String get unsupportedLabel => '未対応';

  @override
  String get differenceAdded => '追加';

  @override
  String get differenceRemoved => '削除';

  @override
  String get differenceChanged => '変更';

  @override
  String get selectHistoryEntry => '履歴の項目を選択';

  @override
  String get searchSqlTarget => 'SQL または対象を検索';

  @override
  String get closeSqlTab => 'SQL タブを閉じる';

  @override
  String get historyMetadataRetained => '状態と対象のメタデータは履歴に残ります。';

  @override
  String get historyPreviewNote =>
      'プレビューのみ。保持されたテキストを取得するには新しい SQL タブで開いてください。';

  @override
  String get selected => '選択済み';

  @override
  String get authReviewNote =>
      '適用前に正確なユーザーまたはロールと対象を確認してください。認証情報は SQL ドキュメントや履歴に置かれません。既存の接続と保存済みパスワードは別のままです。';

  @override
  String get createLogin => 'ログインアカウントを作成';

  @override
  String get createRole => 'ログイン不可のロールを作成';

  @override
  String get setPassword => 'パスワードを設定';

  @override
  String get preventLogin => '新しいログインを禁止';

  @override
  String get allowLogin => '新しいログインを許可';

  @override
  String get dropPrincipal => 'ユーザーまたはロールを削除';

  @override
  String get principalName => '正確なユーザーまたはロール名';

  @override
  String get accountHost => '正確なアカウントホスト（ワイルドカードはログイン範囲を広げます）';

  @override
  String get newPassword => '新しいパスワード';

  @override
  String get repeatPassword => '新しいパスワードを再入力';

  @override
  String get reviewAccount => 'アカウント操作を確認';

  @override
  String get passwordsMismatch => '同じ空でないパスワードを 2 回入力してください';

  @override
  String get accountSubmitFailed =>
      'アカウント操作を送信できませんでした。対象、認証ポリシー、データベース権限を確認してください。';

  @override
  String get privilegeReviewNote =>
      '直接付与された権限を確認してください。生成 SQL には引き続き実行前の確認が必要です。';

  @override
  String get inspectionLimited =>
      '各セクションは 500 行までです。検索を絞ってください。空のセクションは実効アクセス権がない証拠にはなりません。';

  @override
  String get findPrincipal => 'ユーザー名 / ロール名を検索';

  @override
  String get searchPrincipals => 'ユーザーとロールを検索';

  @override
  String get choosePrincipal => 'ユーザーまたはロールを選択';

  @override
  String get inspectGrants => '選択した権限を確認';

  @override
  String get tablePrivileges => 'テーブル / ビューの権限';

  @override
  String get schemaPrivileges => 'スキーマの権限';

  @override
  String get databasePrivileges => 'データベースの権限';

  @override
  String get roleMembership => 'ロールのメンバーシップ';

  @override
  String get defaultRole => '既定ロールの有効化';

  @override
  String get chooseGrantRole => '付与 / 取り消すロールを選択';

  @override
  String get tableView => 'テーブル / ビュー';

  @override
  String get explicitPrivileges => '明示的な権限（カンマ区切り）';

  @override
  String get setDefaultRole => '選択した既定ロールを設定';

  @override
  String get clearDefaultRole => '既定ロールを解除';

  @override
  String get grantAccess => 'アクセス権を付与';

  @override
  String get revokeAccess => 'アクセス権を取り消す';

  @override
  String get withoutDelegation => '委任なし';

  @override
  String get allowDelegation => '受領者による他者への付与を許可';

  @override
  String get readonlyChanges => 'このプロファイルは読み取り専用です。変更には明示的に書き込み可能なセッションが必要です。';

  @override
  String get createPrincipal => 'ユーザー / ロールを作成';

  @override
  String get manageAuthentication => '選択した認証を管理';

  @override
  String get openPrivilegeSql => '権限 SQL を確認用に開く';

  @override
  String get inspectPrincipalFirst => '変更の作成前に選択したユーザーまたはロールを確認';

  @override
  String get accountAuthentication => 'アカウント認証';

  @override
  String get schema => 'スキーマ';

  @override
  String get available => '利用可能';

  @override
  String get availableEmpty => '利用可能 · データなし';

  @override
  String get limitedVisibility => '表示範囲が限定';

  @override
  String get permissionDenied => '権限が拒否されました';

  @override
  String get unavailable => '利用不可';

  @override
  String get profileDisabled => 'プロファイルによって無効';

  @override
  String get unknownState => '不明';

  @override
  String get inspecting => '確認中…';

  @override
  String get refreshCapabilities => '機能を更新';

  @override
  String get staleRefresh => '古い情報 · 接続後に更新';

  @override
  String get staleContext => '古い情報 · 接続やコンテキスト変更後に更新';

  @override
  String get partialTreeLimit => '一部 · ツリーの上限です。データベースオブジェクト検索を絞ってください';

  @override
  String get schemaComparison => 'スキーマ比較';

  @override
  String get searchTable => 'テーブルを検索';

  @override
  String get focusObject => 'フォーカス';

  @override
  String get exportSvg => 'SVG をエクスポート';

  @override
  String get exportPng => 'PNG をエクスポート';

  @override
  String get diagramNotes => '図のメモ（SVG に含まれる）';

  @override
  String get openNotes => 'メモを開く';

  @override
  String get saveNotes => 'メモを保存';

  @override
  String get newSnippet => '新しいスニペット';

  @override
  String get snippetName => 'スニペット名';

  @override
  String get saveSnippet => 'スニペットを保存';

  @override
  String get deleteSnippet => '保存済みスニペットを削除';

  @override
  String get insertSnippet => 'SQL ドキュメントに挿入';

  @override
  String get snippetEditor => 'SQL スニペットエディター';

  @override
  String get snippetsNote =>
      '保存済みのローカル SQL を対象ドキュメントに元に戻せる形で挿入します。実行には明示操作が必要です。';

  @override
  String get level => 'レベル';

  @override
  String get expanded => '展開済み';

  @override
  String get collapsed => '折りたたみ済み';

  @override
  String get treeLevel => 'レベル';

  @override
  String get retainedView => '保持されたビュー';

  @override
  String get tableQuerySnapshot => 'テーブルクエリのスナップショット';

  @override
  String get originalResultNote => '元の保持結果。ページングと検査では SQL を実行しません';

  @override
  String get tableFilterNote => '適用すると確認済みの新しいクエリを送信します。以前のスナップショットは保持されます。';

  @override
  String get retainedFilterNote =>
      '固定スナップショット内の取得済み全行。SQL は再実行しません。保持値の順序はデータベース照合順序と異なる場合があります。';

  @override
  String get retainedRowNote => '取得済みの結果内の行を選択してください。SQL は再実行しません。';

  @override
  String get copyLimitNote => 'コピーは 10,000 セルまで。大きな範囲は保持データをエクスポートしてください。';

  @override
  String get inlineValueLimit => 'セル内編集は 8KiB までの値に対応';

  @override
  String get editContextChanged =>
      '元のセッションまたは編集コンテキストが変わりました。変更の準備前に評価を確認または更新してください';

  @override
  String get editAssessmentUnavailable =>
      '編集の可否を確認できません。セッションがアイドル状態で評価を更新してください';

  @override
  String get rowChangeReverted => '保留中の行変更を元に戻しました。データベースは変更されていません';

  @override
  String get sqlCopyRequiresMetadata => 'SQL コピーにはバックエンドと保持された型メタデータが必要です。';

  @override
  String get exportFullValue => '保持された値全体をエクスポート';

  @override
  String valueExportReview(String bytes, String path) {
    return '$bytes バイトを $path に保存しますか？既存の内容は置き換わります。SQL は再実行しません。';
  }

  @override
  String get goToRetainedRow => '保持された行へ移動';

  @override
  String get row => '行';

  @override
  String get go => '移動';

  @override
  String get retryRows => '保持された行を再取得';

  @override
  String get previousRows => '前の行';

  @override
  String get nextRows => '次の行';

  @override
  String get firstWindow => '最初の保持ウィンドウ';

  @override
  String get lastWindow => '最後の取得ウィンドウ';

  @override
  String get setNull => 'NULL を設定';

  @override
  String copyFormat(String format) {
    return '$format をコピー';
  }

  @override
  String get textValue => 'テキスト';

  @override
  String get sqlValues => 'SQL 値';

  @override
  String get rowSelection => '行選択';

  @override
  String selectRow(String row) {
    return '行 $row を選択';
  }

  @override
  String columnHeader(String column) {
    return '列 $column';
  }

  @override
  String get pendingChange => '保留中の変更';

  @override
  String get readonlyCell => '読み取り専用セル';

  @override
  String get editableCell => '編集可能なセル';

  @override
  String get loadValueFirst => 'この保持値を先に読み込んでください';

  @override
  String get editUnavailable => '編集できません';

  @override
  String get editCell => 'セルを編集';

  @override
  String get unsupportedEditValue => 'この保持値は検査のみ可能です';

  @override
  String bytesCount(String bytes) {
    return '$bytes バイト';
  }

  @override
  String get problems => '問題';

  @override
  String get ownedSessions => '所有セッション';

  @override
  String get noProblems => '記録された問題はありません';

  @override
  String get duplicateConnection => '接続を複製';

  @override
  String get deleteConnection => '接続を削除';

  @override
  String deleteConnectionReview(String name) {
    return '$name を削除しますか？既存の物理セッションは元の設定を保持します。';
  }

  @override
  String get unresolvedSessions => '未解決のセッション';

  @override
  String get disconnectSessionNote =>
      '先に実行中のジョブとトランザクションを解決してください。切断はこの物理セッションのすべてのクライアントに影響します。コミットや SQL の再実行は行いません。不明な結果は不明なままです。';

  @override
  String get transferSettingsChanged => '設定が変更されました。再確認してください';

  @override
  String get transferReviewReady => '確認準備完了 · 対象、範囲、マッピング、ファイルを確認';

  @override
  String get sourcePreviewNotice => 'ソースのプレビュー · 行はインポートされていません';

  @override
  String get transferRequiresReview => '先にこの転送を確認してください';

  @override
  String get transferSubmittedNotice => '送信済み · キャンセルは確定済みコミットや公開ファイルを取り消しません';

  @override
  String get sqlExportExecutionNote => '新しい確認済み SQL 実行';

  @override
  String get retainedExportSnapshotNote => '取得済みスナップショット。SQL は実行しません';

  @override
  String get restorePartialCommitNote => '復元は一部をコミットする場合があります。キャンセルで元には戻りません。';

  @override
  String get sourcePreviewLimit => 'ソースのプレビュー · 最大20行';

  @override
  String get importBatchSafetyNote =>
      'エラーやキャンセルでも以前のバッチコミットは保持されます。送信前にハッシュと不変のソースを検証します。';

  @override
  String get nullMarkerLiteralNote => '引用符なしの NULL マーカー。引用すると文字列です';

  @override
  String immutableSourceHash(String hash) {
    return '不変ソースの SHA-256: $hash';
  }

  @override
  String sourceColumnLabel(String column) {
    return 'ソース列 $column';
  }

  @override
  String previewRowLabel(String row, String column, String value) {
    return 'プレビュー行 $row、$column: $value';
  }

  @override
  String get transferCancellationNotice => 'キャンセル要求済み · 応答を待機';

  @override
  String transferProgress(String processed, String committed, String rejected) {
    return '$processed 処理 · $committed コミット · $rejected 拒否';
  }

  @override
  String get importAtomicPolicy => '全行を1つのトランザクションで';

  @override
  String get importBatchPolicy => 'バッチをコミット。エラーで停止';

  @override
  String get importSkipPolicy => '無効な行をスキップ。バッチをコミット';

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
    return '応答待ち/接続: $operations\n未保存の文書: $documents\n保存中: $saves\n保留中の変更: $edits\n実行中のジョブ: $jobs\n終了処理が必要なトランザクション: $transactions\n不明な結果: $unknown\n不確実なセッション: $sessions';
  }

  @override
  String get closeDraftSaved => 'SQL の下書きをローカルに保存します。';

  @override
  String get closeDraftLost => '復旧が無効です。未保存の SQL と設計は失われます。';

  @override
  String get closeDesignRecovery =>
      '設計は非公開の制限付き復旧を使用します。再度開いたら明示的に接続し、メタデータを調べてください。';

  @override
  String get closeCleanupReview =>
      '最後のセッション所有者を閉じるとキャンセルを要求し、確認済みトランザクションをロールバックして切断します。不明な結果は不明のままです。閉じる操作は SQL をコミットも再実行もしません。';

  @override
  String get closeSharedSession => '他のクライアントは共有の物理セッションを保持します。';

  @override
  String get closeStagedRecovery => '変更には確認済みの非公開復旧、明示的な再接続、新しいレビューが必要です。';

  @override
  String get closeRecoveryLoss =>
      '文書と配置を保存できませんでした。閉じると SQL や変更が失われる場合があります。既存ファイルと復旧データは保持します。';

  @override
  String get closeWaitNotice => '閉じる前に応答と接続の終了処理を待ってください。';

  @override
  String get saveFailedNotice => 'SQL の保存に失敗しました。変更済み SQL を保持するか、明示的に破棄してください。';

  @override
  String get closeCleanupFailed => 'バックエンド終了処理に失敗しました。BusyData は開いたままです。';

  @override
  String get closeBackendUnverified => 'バックエンドの状態が未確認です。作業が残っている場合があります。';

  @override
  String historyRetainSqlReview(String days) {
    return 'SQL に秘密情報が含まれる場合があります。テキストを $days 日保存しますか？';
  }

  @override
  String get historyStopSqlReview => 'SQL の保存を停止し、既存の履歴から削除しますか？';

  @override
  String get historyClearReview => 'すべての履歴を削除しますか？実行中のジョブは終了時に結果を記録する場合があります。';

  @override
  String get historyDeleteReview => '選択した履歴を削除しますか？';

  @override
  String get historyRetentionRange => '保存期間は1–3650日です';

  @override
  String get enableSqlHistory => 'SQL 履歴を有効にする';

  @override
  String get stopSqlHistory => 'SQL の保存を停止';

  @override
  String get recoveryDiscardReview =>
      '復旧記録を破棄しますか？先に不明な結果を確認してください。破棄はコミット済みの変更を取り消しません。';

  @override
  String closeSqlSummary(String unsaved, String edits, String jobs) {
    return '未保存の SQL: $unsaved\n保留中の変更: $edits\n実行中のジョブ: $jobs';
  }

  @override
  String get recoveryStayOpen => '復旧に失敗しました。BusyData は開いたままで、未保存の作業は保持されます。';

  @override
  String get commitUncertaintyNote =>
      'ネットワーク障害でコミット結果が不明になる場合があります。自動で再試行しないでください。';

  @override
  String get closeObjectDesignDiscard =>
      '未保存の設計フィールドは破棄されます。設計を残すには先に SQL を生成して保存してください。';

  @override
  String get savePrivateDrafts => '非公開の復旧下書きを保存';

  @override
  String get noPrivateDrafts => '復旧下書きを保存しない';

  @override
  String shortcutField(String command) {
    return '$command のショートカット';
  }

  @override
  String get shortcutInvalid =>
      '他の操作に割り当てられていない有効なショートカットを使用してください。F6 と Shift+F6 は予約済みです。';

  @override
  String get disableRecoveryReview =>
      'SQL、設計、変更のローカル復旧を削除しますか？未保存の作業は開いたままですが、クラッシュで失われる場合があります。先に不明な結果を確認してください。';

  @override
  String get preferencesSaved => '設定を保存しました';

  @override
  String get sharingSessionReview =>
      'このクエリは指定した物理セッション、トランザクション、一時オブジェクト、設定を表示されたクライアントと共有します。1つを閉じても他は保持されます。';

  @override
  String get recoveryReconcileFirst =>
      '復旧を無効にする前に、適用中や不明な変更を確認してください。復旧記録の破棄には個別の明示的なレビューが必要です。';

  @override
  String get enterSearchText => '検索テキストを入力';

  @override
  String get noSearchMatches => '一致なし';

  @override
  String searchMatchCount(String position, String total) {
    return '$total 件中 $position 件目';
  }

  @override
  String get formatSqlChanged =>
      'SQL または対象が変更されました。元の SQL は保持されています。新しい整形プレビューを取得してください。';

  @override
  String get formatSqlUnavailable =>
      '不完全・未対応の構文または解析制限により整形できません。元の SQL は保持されています。';

  @override
  String get stageChange => '変更を仮登録';

  @override
  String pendingChangesCount(String count) {
    return '保留中の変更 $count 件。確認済み適用までデータベースは変更されません。';
  }

  @override
  String discardChangesCount(String count) {
    return '保留中の変更 $count 件を破棄しますか？データベース操作は送信されません。';
  }

  @override
  String get recoveryNoExecution =>
      '復元は接続、元の SQL の実行、トランザクション再開、変更の再実行を行いません。結果不明・コミット済み記録は再適用できません。';

  @override
  String get recoveredDesign =>
      '設計を復元しました。明示的に接続し、現在のメタデータを確認してから新しいレビューを生成してください。復元時に SQL やメタデータを取得していません。';

  @override
  String get retainedUnavailable =>
      '保持データを利用できません。保存 SQL と非公開の復元データはローカルに残ります。';

  @override
  String get activityFingerprintNote =>
      '選択した活動のフィンガープリントは送信前に再検証されます。書き込み結果が不明になる場合があります。';

  @override
  String replaceFileReview(String path) {
    return '確認済みファイル $path を置き換えますか？保存先の変更には再確認が必要です。';
  }

  @override
  String get diagramPngSaved => '図の PNG を保存しました。長いメモは最大 6 行表示します。';

  @override
  String get editTargetChanged => '編集対象が変更されました。仮登録前に行エディターを開き直してください。';

  @override
  String affectedRowCount(String count) {
    return '影響を受けた行: $count';
  }

  @override
  String get zoomIn => '拡大';

  @override
  String get zoomOut => '縮小';

  @override
  String get resetView => '表示をリセット';

  @override
  String get diagramKeys => '矢印で移動、+ と - で拡大・縮小、Home で表示をリセットします。';

  @override
  String get explorerConnected => 'エクスプローラー接続済み';

  @override
  String get explorerDisconnected => 'エクスプローラー未接続';

  @override
  String querySessionCount(String count) {
    return 'クエリセッション $count';
  }

  @override
  String get metadataColumn => '列';

  @override
  String get metadataPosition => '位置';

  @override
  String get metadataUnique => '一意';

  @override
  String get metadataJdbcType => 'JDBC 型';

  @override
  String get metadataAutoIncrement => '自動増分';

  @override
  String get metadataReferencedColumn => '参照先の列';

  @override
  String get metadataComment => 'コメント';

  @override
  String get metadataType => '種類';

  @override
  String get metadataEvent => 'イベント';

  @override
  String get metadataSpecificName => 'ネイティブの固有識別子';

  @override
  String get metadataOptions => 'オプション';

  @override
  String get metadataInheritance => '継承';

  @override
  String get metadataDefinitionCaptured => '取得済みのネイティブ定義';

  @override
  String get metadataDefinitionUnavailable => '取得済みメタデータでは定義を利用できません';

  @override
  String get metadataDefinitionUnsupported => '取得したオブジェクトに対応するネイティブ定義はありません';

  @override
  String get connections => '接続';

  @override
  String get noConnections => '接続はまだありません';

  @override
  String get startTitle => 'データベースに接続';

  @override
  String get startDescription =>
      'PostgreSQL、MySQL、MariaDBに接続して、オブジェクトの参照、データの管理、クエリの実行を行います。';

  @override
  String get savedStartTitle => '接続を選択';

  @override
  String get savedStartDescription =>
      'データベースエクスプローラーの保存済み接続から、オブジェクトを参照してクエリを実行できます。';

  @override
  String get noConnection => '接続なし';

  @override
  String queryTitle(int number) {
    return 'クエリ $number';
  }

  @override
  String get sessionMenu => 'セッション';

  @override
  String get noFilterMatches => '一致する接続または読み込み済みオブジェクトはありません';

  @override
  String get activityState => '状態';

  @override
  String get activityWait => '待機';

  @override
  String get generalSettings => '一般';

  @override
  String get optionsSettings => 'オプション';

  @override
  String get host => 'ホスト';

  @override
  String get databaseSystem => 'データベースシステム';

  @override
  String get passwordStorage => 'パスワードの保存';

  @override
  String get environmentLabel => '環境';

  @override
  String get readOnlySettings => '読み取り専用ポリシー';

  @override
  String get tlsPolicy => 'TLS ポリシー';

  @override
  String get sshConnection => 'SSH 接続';

  @override
  String get sshAuthentication => 'SSH 認証';

  @override
  String get connectionTestAction => '接続をテスト';

  @override
  String get details => '詳細';

  @override
  String get copyDetails => '詳細をコピー';

  @override
  String get retry => '再試行';

  @override
  String get filterCellValue => 'この値で絞り込み';

  @override
  String get connectsWhenRun => '実行時に接続';

  @override
  String get connectionSaving => '保存…';

  @override
  String get connectionConnecting => '接続…';

  @override
  String get connectionCancelling => 'キャンセル…';

  @override
  String get connectionSettingsChanged => '設定が変更されました。この版を再テストしてください。';

  @override
  String get connectionTestChanged => '設定が変更されました。この版を再テストしてください。';

  @override
  String get connectionRequired => '必須';

  @override
  String get connectionCorrectFields => '指定された設定を確認してください。';

  @override
  String get connectionHostname => 'ホスト · 指定された設定を確認してください。';

  @override
  String get connectionSshHostname => 'SSH · ホスト · 指定された設定を確認してください。';

  @override
  String get connectionMaxLength => '名前 ≤ 256';

  @override
  String get connectionTlsHelp => 'TLS · ホスト · SSH/SSL. 指定された設定を確認してください。';

  @override
  String get connectionTlsReview => 'TLS · ホスト · SSH/SSL. 指定された設定を確認してください。';

  @override
  String get connectionStorageUnavailable => 'パスワードの保存: 利用不可. パスワード · 保存しない.';

  @override
  String get connectionHostReviewed => 'ホスト · 信頼はこのプロファイルと正確な接続先のみに適用されます。';

  @override
  String get connectionSshReviewing => 'SSH · SSH ホスト鍵を確認…';

  @override
  String get connectionFailureAuthentication =>
      '失敗 · 認証 · 一般. 指定された設定を確認してください。';

  @override
  String get connectionFailureTls => '失敗 · TLS · SSH/SSL. 指定された設定を確認してください。';

  @override
  String get connectionFailureSshKey => '失敗 · SSH ホスト鍵を確認. 指定された設定を確認してください。';

  @override
  String get connectionFailureEndpoint => '失敗 · ホスト · ポート. 指定された設定を確認してください。';

  @override
  String get connectionFailureCancelled => 'キャンセル済み';

  @override
  String get connectionFailureSettings => '失敗 · 一般. 指定された設定を確認してください。';

  @override
  String get connectionFailureAccess => '失敗 · テーブル / ビューの権限. 指定された設定を確認してください。';

  @override
  String get connectionFailureUnavailable =>
      '失敗 · ホスト · TLS · SSH. 指定された設定を確認してください。';

  @override
  String get connectionFailureTimeout =>
      '失敗 · 接続タイムアウト · 1–120 秒. 指定された設定を確認してください。';

  @override
  String get connectionFailureUnknown =>
      '失敗 · 一般 · TLS · SSH. 指定された設定を確認してください。';

  @override
  String connectionNumber(int min, int max) {
    return '$min～$max の整数を入力してください';
  }

  @override
  String connectionSavedFailure(String name) {
    return '接続を保存しました: $name。接続の試行に失敗しました。 ';
  }

  @override
  String get backendBusy => 'バックエンドが処理中です。現在のリクエストが完了してから再試行してください。';

  @override
  String rpcRequestUnconfirmed(String code) {
    return 'リクエストは確認されませんでした（RPC $code）。';
  }

  @override
  String get operationUnconfirmed => '操作を完了できませんでした。';

  @override
  String get connectionFailureTlsMaterial =>
      'TLS 素材が利用できないか無効です。SSH/SSL で信頼ソースとクライアント鍵を確認してください。';

  @override
  String get managerTitle => 'データソースとドライバー';

  @override
  String get sourceListTitle => 'データソース';

  @override
  String get driverLabel => 'ドライバー';

  @override
  String get connectionTypeLabel => '接続タイプ';

  @override
  String get defaultTcp => 'デフォルト (TCP)';

  @override
  String get authenticationLabel => '認証';

  @override
  String get userPasswordAuth => 'ユーザーとパスワード';

  @override
  String get neverStorage => '保存しない';

  @override
  String get initialDatabaseLabel => '初期データベース';

  @override
  String get useSshTunnel => 'SSH トンネルを使用';

  @override
  String get sshConfigurationLabel => 'SSH 構成';

  @override
  String get createSshConfig => '<構成を作成>';

  @override
  String get copySshSettings => 'SSH 設定をコピー';

  @override
  String get localPortLabel => 'ローカルポート';

  @override
  String get dynamicPortLabel => '<動的>';

  @override
  String get useSsl => 'SSL を使用';

  @override
  String get useTruststore => 'トラストストアを使用';

  @override
  String get clientKeyPasswordLabel => 'クライアント鍵のパスワード';

  @override
  String get modeLabel => 'モード';

  @override
  String get requireTls => '必須';

  @override
  String get verifyCa => 'CA を検証';

  @override
  String get fullVerification => '完全検証';

  @override
  String get connectionSection => '接続';

  @override
  String get configurationApplied => '構成を適用しました';

  @override
  String get noOtherSshConfig => '他のソースには SSH 構成がありません。';

  @override
  String get generatedUrlHelp => '生成された読み取り専用の JDBC アドレスです。';

  @override
  String get tlsDriverDefaultHelp => 'SSL は未構成です。同梱ドライバーのデフォルトを使用します。';

  @override
  String get tlsClientKeyHelp =>
      'PEM 鍵：PKCS#8 または OpenSSL。暗号化された鍵と暗号化されていない鍵に対応。';

  @override
  String get legacyMariaTrustHelp =>
      '既存のドライバー検証を維持します。信頼ソースを選択してルートを明示的に構成します。';

  @override
  String get metadataStartValue => '開始値';

  @override
  String get metadataMinimumValue => '最小値';

  @override
  String get metadataMaximumValue => '最大値';

  @override
  String get metadataIncrement => '増分';

  @override
  String get metadataCycle => '循環';

  @override
  String get metadataCacheSize => 'キャッシュサイズ';

  @override
  String get metadataLastValue => '最終値';

  @override
  String get sequences => 'シーケンス';

  @override
  String get namespaceSelection => '名前空間を選択';

  @override
  String get namespaceSelectionNotice =>
      '選択はイントロスペクションを制御します。クエリコンソールの実行コンテキストは維持されます。';

  @override
  String get allNamespaces => 'すべての名前空間';

  @override
  String get defaultNamespace => '既定';

  @override
  String get namespacePattern => '名前のパターン（正規表現）';

  @override
  String namespaceCount(int selected, int known) {
    return '$known 中 $selected';
  }

  @override
  String get previousPage => '前のページ';

  @override
  String get patternRejected => 'パターンが無効か、処理制限を超えています。以前の選択を保持します。';

  @override
  String get namespaceNotSelected => 'イントロスペクションの対象に選択されていない名前空間';

  @override
  String get newMenu => '新規';

  @override
  String get queryConsoles => 'クエリコンソール';

  @override
  String get viewOptions => '表示オプション';

  @override
  String get quickDocumentation => 'クイックドキュメント';

  @override
  String get showEmptyGroups => '空のグループを表示';

  @override
  String get speedSearch => 'スピード検索';

  @override
  String get speedSearchScope => '展開済みで読み込まれたノードのみ。';

  @override
  String get newSourceFolder => '新しいデータソースフォルダー';

  @override
  String get renameSourceFolder => 'フォルダー名を変更';

  @override
  String get moveToFolder => 'フォルダーへ移動';

  @override
  String get moveUp => '上へ移動';

  @override
  String get moveDown => '下へ移動';

  @override
  String get folderMustBeEmpty => '削除する前に、フォルダー内のデータソースとフォルダーを移動してください。';

  @override
  String get newVirtualView => '新しい仮想ビュー';

  @override
  String get editVirtualDefinition => 'ローカル定義を編集';

  @override
  String get unboundVirtualView => '未接続の仮想ビュー';

  @override
  String get localVirtualViewNotice =>
      'ローカル SQL 定義です。保存しても SQL は実行されず、サーバービューも作成されません。実行には通常の SQL レビューと独立したコンソールを使用します。';

  @override
  String get rebindVirtualView => 'ローカル定義をここに関連付ける';

  @override
  String get sourceFolderName => 'フォルダー名';

  @override
  String get sourceFolderPathNotice => '/ で入れ子のフォルダーを作成できます。';

  @override
  String get topLevel => '最上位';

  @override
  String get virtualViewName => '仮想ビュー名';

  @override
  String get virtualViewSql => '仮想ビューの SQL 定義';

  @override
  String get virtualViews => '仮想ビュー';

  @override
  String get revealInExplorer => 'データベースエクスプローラーに表示';

  @override
  String get objectNotFound => 'この名前空間にオブジェクトが見つかりません。メタデータを更新するか権限を確認してください。';

  @override
  String get objectHiddenByFilter => '現在の表示フィルターでオブジェクトが非表示になっています。';

  @override
  String get revealFilterNotice => 'オブジェクト検索でこのページを絞り込み中のため、カテゴリの総数は表示しません。';

  @override
  String get clearObjectFilter => 'オブジェクト検索を解除';

  @override
  String get compareStructure => '構造を比較';

  @override
  String get selectTwoCompatibleObjects => 'Ctrl を押しながら互換性のあるテーブルを2つ選択してください。';

  @override
  String get scopedComparisonRestriction =>
      '比較には同じネイティブ名、スキーマ、エンジンの通常テーブルが必要です。他の種類と名前変更の照合は利用できません。';

  @override
  String get groupNamespaces => 'データベースとスキーマをグループ化';

  @override
  String get groupSchemaObjects => 'スキーマオブジェクトをグループ化';

  @override
  String get groupTableElements => 'テーブル要素をグループ化';

  @override
  String get sortAlphabetically => '名前順に並べ替え';

  @override
  String get showVirtualObjects => '仮想オブジェクトを表示';

  @override
  String get showObjectComments => 'オブジェクトのコメントを表示';

  @override
  String get objectTypeFilter => 'オブジェクト種類フィルター';

  @override
  String get partitionedTable => 'パーティションテーブル';

  @override
  String get foreignTable => '外部テーブル';

  @override
  String get materializedView => 'マテリアライズドビュー';

  @override
  String get functionObject => '関数';

  @override
  String get procedureObject => 'プロシージャ';

  @override
  String get sqlSymbolUnavailable =>
      'カーソル位置の永続オブジェクトを安全に解決できません。このコンソールを接続し、リテラルやコメント以外のテーブルまたはビューの参照を使用してください。';

  @override
  String get sqlSymbolAmbiguous =>
      'SQL オブジェクトの参照が曖昧です。名前空間を修飾するか、正確なデータベースオブジェクトを選択してください。';

  @override
  String get deactivateSource => 'データソースを無効化';

  @override
  String get functions => '関数';

  @override
  String get procedures => 'プロシージャ';

  @override
  String get separateProceduresFunctions => 'プロシージャと関数を分ける';

  @override
  String get renameVirtualView => '仮想ビューの名前を変更';

  @override
  String get metadataPersistentScope =>
      '永続オブジェクトのみ。一時オブジェクトとセッション固有のオブジェクトはコンソールで参照できます。';

  @override
  String get metadataSessionScope => '永続オブジェクトのみ。実行後にコンソール固有のオブジェクトを更新してください。';

  @override
  String get metadataLimitScope => 'メタデータの上限に達しました。オブジェクトの範囲を絞ってください。';

  @override
  String get completeColumnMetadataRequired => 'インポートや変更の準備には、列の完全なメタデータが必要です。';

  @override
  String resizeColumn(String name) {
    return '列 $name の幅を変更';
  }

  @override
  String get keyboardShortcutsHeading => 'キーボードショートカット';

  @override
  String sqlEditorLabel(String title) {
    return 'SQL エディター $title';
  }

  @override
  String get editorResultsDivider => 'エディターと結果の区切り';

  @override
  String editorExtent(String percent) {
    return 'エディター $percent パーセント';
  }

  @override
  String get largerEditor => 'エディターを広げる';

  @override
  String get smallerEditor => 'エディターを狭める';

  @override
  String get explorerWidthDivider => 'エクスプローラーの幅の区切り';

  @override
  String get widerExplorer => 'エクスプローラーを広げる';

  @override
  String get narrowerExplorer => 'エクスプローラーを狭める';

  @override
  String explorerExtent(String width) {
    return '幅 $width ピクセル';
  }

  @override
  String planTextPage(String start, String end, String total) {
    return '全 $total UTF-16 単位中 $start–$end';
  }

  @override
  String get dropDesignedColumn => '列を削除';

  @override
  String get liveCatalogLabel => '現在のカタログ';

  @override
  String get liveSchemaLabel => '現在のスキーマ';

  @override
  String get searchPathLabel => '検索パス';

  @override
  String get physicalSessionLabel => '物理セッション';

  @override
  String queryTimeoutDetail(String seconds, String rows) {
    return 'タイムアウト: $seconds 秒 · 行数制限: $rows';
  }

  @override
  String get saveFailedCloseTitle => 'SQL の保存に失敗 · BusyData を閉じる';

  @override
  String get createSection => '作成';

  @override
  String get newConnectionDescription => 'データベース接続を設定';

  @override
  String get newQueryDescription => '新しいクエリで SQL を記述';

  @override
  String get openSqlDescription => '既存の SQL 文書を開く';

  @override
  String get searchNoResults => '一致する操作がありません';

  @override
  String get actionsCategory => '操作';

  @override
  String get privateRecoveryCategory => '非公開の復元';

  @override
  String get shortcutRecordHelp =>
      'ショートカットを押してください。Escape でキャンセル。F6 と Shift+F6 はペイン移動用です。';

  @override
  String get rowLimitInvalid => '行数の上限を 1～1,000,000 で入力してください。';

  @override
  String get errorPolicy => '実行エラー時';

  @override
  String get tlsEncrypted => '暗号化あり';

  @override
  String get tlsUnencrypted => '暗号化なし';

  @override
  String get tlsUnobserved => '未観測';

  @override
  String get encryptionVerificationNote => '暗号化は証明書やホスト名の検証を保証しません。';

  @override
  String get uniqueDesignedColumnName => '一意の列名を使用してください。新しいテーブルは最大 128 列です';

  @override
  String activityBlockerUnavailable(String id) {
    return 'ブロッカー $id は表示されなくなりました。更新してデータベース権限を確認してください';
  }

  @override
  String get sshChangedKeyReview =>
      'このプロファイルとの関連付けを置換する前に、変更された鍵を別の方法で検証してください。';

  @override
  String get sshProfileTrustBinding => '信頼はこのプロファイルと正確な接続先のみに適用されます。';

  @override
  String get databaseTlsEvidence => 'TLS · データベースシステム';

  @override
  String get sshAlgorithmLabel => 'SSH · 種類';

  @override
  String get sshFingerprintLabel => 'SHA-256';

  @override
  String get sshPreviousFingerprintLabel => '前へ · SHA-256';

  @override
  String get sshReviewedLabel => 'SSH ホスト鍵を確認';

  @override
  String get shortcutRecordAction => 'ショートカットを記録';

  @override
  String get fileFormatLabel => 'ファイル形式';

  @override
  String get encodingLabel => '文字コード';

  @override
  String get importPolicyLabel => 'インポート方針';

  @override
  String get mainMenu => 'メインメニュー';

  @override
  String get activityReplyTooLarge => 'アクティビティの応答がインスペクターの上限を超えています。';

  @override
  String get activityListLimited => '一覧は制限されています。明示的な SQL で対象を絞って調べてください。';

  @override
  String get activitySelectionChanged =>
      '選択したアクティビティは終了または変更されました。操作を確認する前に現在の識別情報を選択してください。';

  @override
  String connectionSavedDraftChanged(String name) {
    return '保存中に接続項目が変更されました。設定は保存済みです: $name。接続する前に現在の値を確認してください。';
  }

  @override
  String get sshReviewTargetChanged => 'SSH の確認対象が変更されました。もう一度確認してください';

  @override
  String get appearance => '外観';

  @override
  String get theme => 'テーマ';

  @override
  String get systemTheme => 'システム';

  @override
  String get lightTheme => 'ライト';

  @override
  String get darkTheme => 'ダーク';

  @override
  String get appLanguage => '言語';

  @override
  String get systemLanguage => 'システム';

  @override
  String get cut => '切り取り';

  @override
  String get paste => '貼り付け';

  @override
  String get selectAll => 'すべて選択';

  @override
  String get noSelection => 'テキストがありません';

  @override
  String get clipboardEmpty => 'クリップボードにテキストがありません';

  @override
  String get settingsDraftNotice => '実行とプライベート復元の変更は保存されていません。';

  @override
  String get documentsMenu => 'ドキュメント';

  @override
  String get currentSql => '現在の SQL';

  @override
  String get searchActionsHint => 'アクションを検索…';

  @override
  String get searchCurrentSqlHint => 'Search current SQL…';

  @override
  String get searchObjectsHint => 'Search database objects…';

  @override
  String get searchHistoryHint => 'Search query history…';

  @override
  String get metadataAttributes => '属性';

  @override
  String get metadataSelectionUnavailable =>
      '記録された属性を確認する項目を選択してください。以前の選択は利用できません。';

  @override
  String get secureStorage => 'OS の安全なストレージ';

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
      'キャッシュを保存できませんでした。現在のメタデータは引き続き利用できます。';

  @override
  String get metadataCacheRebuiltVersion => '現在のバージョン用に再構築済み';

  @override
  String get metadataCacheRebuiltCorrupt => 'キャッシュエラー後に再構築済み';

  @override
  String get editSessionBusy =>
      'このセッションは使用中です。現在の処理が完了するまで待ってから、編集可否の評価を再度リクエストしてください。';

  @override
  String get editIdentityRequired =>
      '編集する前に、主キーまたは NULL を許可しない一意キーの全列を選択してください。';

  @override
  String get editColumnsReadOnly => '射影された列はすべて生成列または読み取り専用の列です。';

  @override
  String get editResultNotReady =>
      '保持されたこの結果が完了するまで待ってから、編集可否の評価を再度リクエストしてください。';

  @override
  String get editProjectionUnsupported =>
      '編集には、各基底列を一度ずつ選択する、単一の基底テーブルからの直接の SELECT が必要です。';

  @override
  String get sqlInspectionDuplicateUsingColumn => 'JOIN USING の列が重複しています';

  @override
  String get sqlInspectionUnresolvedUsingColumn =>
      'JOIN USING の列が一方のオペランドに存在しません';

  @override
  String get sqlInspectionAmbiguousUsingColumn => 'JOIN の共通列が曖昧です';

  @override
  String get sqlInspectionOutputColumnCount => '宣言された出力列の数が一致しません';

  @override
  String get sqlInspectionAmbiguousOverload => 'ルーチンのオーバーロードが曖昧です';

  @override
  String get sqlInspectionBooleanType => 'ブール式の型が無効です';

  @override
  String get sqlInspectionOperatorTypes => '演算子のオペランド型に互換性がありません';

  @override
  String get sqlInspectionArrayTypes => '配列要素の型に互換性がありません';

  @override
  String get sqlInspectionCaseConditionType => 'CASE 条件の型に互換性がありません';

  @override
  String get sqlInspectionCaseResultTypes => 'CASE 結果の型に互換性がありません';

  @override
  String get sqlInspectionCoalesceTypes => 'COALESCE 引数の型に互換性がありません';

  @override
  String get sqlInspectionSetColumnCount => '集合演算の列数が一致しません';

  @override
  String get sqlInspectionSetTypes => '集合演算の結果型に互換性がありません';

  @override
  String get sqlInspectionRecursiveCteType => '再帰 CTE の型が一致しません';
}
