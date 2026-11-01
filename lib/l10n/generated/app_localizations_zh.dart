// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get cancel => '取消';

  @override
  String get windowMinimize => '最小化';

  @override
  String get windowMaximize => '最大化';

  @override
  String get windowRestore => '还原';

  @override
  String get databaseExplorer => '数据库资源管理器';

  @override
  String get databases => '数据库';

  @override
  String get newConnection => '新建连接';

  @override
  String get filterTree => '筛选连接和对象';

  @override
  String get treeFilterScope => '筛选已加载的树对象';

  @override
  String get searchObjects => '搜索数据库对象';

  @override
  String get fileMenu => '文件';

  @override
  String get editMenu => '编辑';

  @override
  String get viewMenu => '视图';

  @override
  String get connectionMenu => '连接';

  @override
  String get objectMenu => '对象';

  @override
  String get runMenu => '执行选项';

  @override
  String get commands => '命令';

  @override
  String get findCommand => '查找命令';

  @override
  String get newSql => '新建查询';

  @override
  String get openSql => '打开 SQL';

  @override
  String get openSqlFile => '打开 SQL 文件';

  @override
  String get saveSql => '保存 SQL';

  @override
  String get closeTab => '关闭标签页';

  @override
  String get openWorkspace => '打开工作区';

  @override
  String get saveWorkspace => '保存工作区';

  @override
  String get settings => '设置';

  @override
  String get findText => '查找';

  @override
  String get replaceText => '替换';

  @override
  String get formatSql => '格式化 SQL';

  @override
  String get lineComments => '切换行注释';

  @override
  String get snippets => 'SQL 代码片段';

  @override
  String get run => '运行';

  @override
  String get runStatement => '运行当前语句';

  @override
  String get runSelection => '运行所选内容';

  @override
  String get runScript => '运行脚本';

  @override
  String get explain => '执行计划';

  @override
  String get explainAnalyze => '执行并分析计划';

  @override
  String get connect => '连接';

  @override
  String get disconnect => '断开连接';

  @override
  String get sessionDetails => '会话详情';

  @override
  String get beginTransaction => '开始事务';

  @override
  String get commitTransaction => '提交事务';

  @override
  String get rollbackTransaction => '回滚事务';

  @override
  String get enableAutoCommit => '启用自动提交';

  @override
  String get disableAutoCommit => '禁用自动提交';

  @override
  String get outcomeUnknown => '结果未知';

  @override
  String get outcomeUnknownNote => '操作可能已完成。此会话无法继续执行 SQL。切勿自动重试；开始新操作前请核实结果。';

  @override
  String get notConnected => '已断开';

  @override
  String get autoCommit => '自动提交';

  @override
  String get manualTransaction => '手动事务';

  @override
  String get readOnlyPolicy => 'BusyData 只读策略';

  @override
  String get data => '数据';

  @override
  String get structure => '结构';

  @override
  String get results => '结果';

  @override
  String get messages => '消息';

  @override
  String get plan => '计划';

  @override
  String get changes => '更改';

  @override
  String get history => '历史记录';

  @override
  String get jobs => '任务';

  @override
  String get retainedResults => '保留的结果';

  @override
  String get recoverEdits => '恢复已暂存更改';

  @override
  String get applyAndCommit => '应用并提交';

  @override
  String get inspectStructure => '检查结构';

  @override
  String get openData => '打开数据';

  @override
  String get openDefinition => '打开定义';

  @override
  String get copyQualifiedName => '复制限定名称';

  @override
  String get refresh => '刷新';

  @override
  String get columns => '列';

  @override
  String get indexes => '索引';

  @override
  String get constraints => '键和约束';

  @override
  String get foreignKeys => '外键';

  @override
  String get triggers => '触发器';

  @override
  String get definition => '定义';

  @override
  String get dependencies => '依赖关系';

  @override
  String get connectionCapabilities => '连接概览';

  @override
  String get sessionsAndLocks => '会话和锁';

  @override
  String get usersAndRoles => '用户和角色';

  @override
  String get saveSnapshot => '保存模式快照';

  @override
  String get compareSchemas => '比较模式';

  @override
  String get objectDesigner => '对象设计器';

  @override
  String get diagram => 'ER 图';

  @override
  String get backup => '备份';

  @override
  String get restore => '还原';

  @override
  String get importData => '导入数据';

  @override
  String get exportRetained => '导出保留数据';

  @override
  String get exportSql => '运行 SQL 导出';

  @override
  String get stageInsert => '插入行';

  @override
  String get stageUpdate => '编辑行';

  @override
  String get stageDelete => '删除行';

  @override
  String get discardChanges => '放弃待处理更改';

  @override
  String get disposeResult => '释放保留数据';

  @override
  String get currentSchema => '当前模式（将被更改）';

  @override
  String get desiredSchema => '期望模式';

  @override
  String get applyTo => '应用到';

  @override
  String get loading => '正在加载';

  @override
  String get empty => '此范围内没有对象';

  @override
  String get more => '更多';

  @override
  String get filter => '筛选';

  @override
  String get sort => '排序';

  @override
  String get selectTarget => '选择连接';

  @override
  String get requireSql => '需要 SQL 文档';

  @override
  String get requireSession => '需要已连接且状态已知的会话';

  @override
  String get requireResult => '需要保留数据';

  @override
  String get requireObject => '需要目标对象';

  @override
  String get cancelRequested => '已请求取消';

  @override
  String get cancelled => '已取消';

  @override
  String get queued => '排队中';

  @override
  String get running => '运行中';

  @override
  String get completed => '已完成';

  @override
  String get failed => '失败';

  @override
  String get partial => '部分';

  @override
  String get sessionSharing => '共享现有会话（高级）';

  @override
  String get production => '生产环境';

  @override
  String get staging => '预发布环境';

  @override
  String get development => '开发环境';

  @override
  String get executionOptions => '执行选项';

  @override
  String get resultRowLimit => '结果行数限制（1–1000000）';

  @override
  String get boundedRead => '有界读取';

  @override
  String get streamingRead => '流式读取 · 持有读取事务';

  @override
  String get stopOnError => '出错时停止脚本';

  @override
  String get continueOnError => '出错时继续 · 先前语句可能已提交';

  @override
  String get loadMore => '加载更多';

  @override
  String get favorite => '切换收藏';

  @override
  String get connectionGroup => '连接分组';

  @override
  String get copyRange => '复制范围';

  @override
  String get inspectValue => '检查值';

  @override
  String get editConnection => '编辑连接';

  @override
  String get chooseSnapshot => '选择快照';

  @override
  String get captureSchema => '捕获模式';

  @override
  String get sameSchemaRestriction => '快照的引擎、模式名称和版本必须相同。比较和保存不会应用更改。';

  @override
  String get restoredTaskState =>
      '已恢复此文档引用。先前的后端数据、会话和任务不可用。请选择明确操作来开始新工作；恢复不会连接、执行 SQL 或重放更改。';

  @override
  String get preChangeSnapshot => '更改前快照 · 更改已提交。请明确刷新以检查当前行和服务器默认值。';

  @override
  String get sqlProvenance => 'SQL 来源';

  @override
  String get assessEditing => '评估可编辑性';

  @override
  String get viewDetails => '查看详情';

  @override
  String get gridMenu => '数据网格';

  @override
  String get visibleColumns => '可见列';

  @override
  String get hidden => '隐藏';

  @override
  String get ascending => '升序';

  @override
  String get descending => '降序';

  @override
  String get equals => '等于';

  @override
  String get notEqual => '不等于';

  @override
  String get lessThan => '小于';

  @override
  String get greaterThan => '大于';

  @override
  String get isNull => '为 NULL';

  @override
  String get isNotNull => '不为 NULL';

  @override
  String get exactValue => '精确值';

  @override
  String get sortTable => '排序表数据';

  @override
  String get filterTable => '筛选表数据';

  @override
  String get sortRetained => '排序保留快照';

  @override
  String get filterRetained => '筛选保留快照';

  @override
  String get applyView => '应用';

  @override
  String get rowsLabel => '行';

  @override
  String get fetchedRows => '已获取行';

  @override
  String get fixedSnapshot => '已获取行的固定快照';

  @override
  String get limitReached => '达到限制';

  @override
  String get retainedData => '保留数据';

  @override
  String get applyRequiresAutoCommit => '应用并提交需要空闲且启用自动提交的会话。';

  @override
  String get connectionProfile => '连接配置';

  @override
  String get basic => '基本';

  @override
  String get advanced => '高级';

  @override
  String get connectionName => '名称';

  @override
  String get hostname => '主机名（也用于 TLS 验证）';

  @override
  String get port => '端口';

  @override
  String get database => '数据库';

  @override
  String get user => '用户';

  @override
  String get password => '密码';

  @override
  String get writableProfile => '可写配置';

  @override
  String get readonlyProfile => '只读配置';

  @override
  String get tlsVerify => 'TLS：验证证书和主机名';

  @override
  String get tlsInsecure => 'TLS：不安全，不验证';

  @override
  String get tlsDisabled => 'TLS：已禁用';

  @override
  String get testConnection => '测试但不保存';

  @override
  String get saveProfile => '保存';

  @override
  String get saveConnect => '保存并连接';

  @override
  String get sessionPassword => '仅本会话使用密码';

  @override
  String get storedPassword => '将密码存入操作系统安全存储';

  @override
  String get chooseFile => '选择文件';

  @override
  String get testRunning => '正在测试连接…';

  @override
  String get cancelTest => '取消测试';

  @override
  String get idle => '空闲';

  @override
  String get activeTransaction => '事务已打开';

  @override
  String get failedTransaction => '事务失败';

  @override
  String get inspectionContext => '检查会话';

  @override
  String get requireTableOrView => '选择表或视图';

  @override
  String get operationPending => '文档操作正在等待确认';

  @override
  String get requirePlan => '选择保留的 Explain 执行';

  @override
  String get openPlanDocument => '打开计划文档';

  @override
  String get locks => '锁';

  @override
  String get statistics => '统计信息';

  @override
  String get queryStatistics => '查询统计';

  @override
  String get indexDiagnostics => '索引诊断';

  @override
  String get grants => '授予的权限';

  @override
  String get sqlExecution => 'SQL 执行';

  @override
  String get planReady => '保留的计划已就绪；SQL 未重新执行';

  @override
  String get executionPlan => '执行计划';

  @override
  String get openOwner => '打开所属文档';

  @override
  String get terminateActivity => '终止活动';

  @override
  String get close => '关闭';

  @override
  String get previous => '上一项';

  @override
  String get next => '下一项';

  @override
  String get replaceSelection => '替换选区';

  @override
  String get replaceAll => '全部替换';

  @override
  String get restartBackend => '重启后端';

  @override
  String get structuredTree => '结构树';

  @override
  String get rawOutput => '原始输出';

  @override
  String get previousTextPage => '上一页文本';

  @override
  String get nextTextPage => '下一页文本';

  @override
  String get filterChangedObjects => '筛选已更改对象';

  @override
  String get rebindVerifiedEdits => '重新绑定已验证的编辑';

  @override
  String get discardRecoveryRecord => '丢弃恢复记录';

  @override
  String get revertChange => '撤销待处理更改';

  @override
  String get chooseSource => '选择源';

  @override
  String get chooseDestination => '选择目标';

  @override
  String get delimiterField => '分隔符（一个字符）';

  @override
  String get batchRowsField => '每批行数（1–1000）';

  @override
  String get rejectedLimit => '拒绝行数上限（1–1000）';

  @override
  String get previewSource => '预览源';

  @override
  String get reviewTransfer => '审核传输';

  @override
  String get startImport => '开始导入';

  @override
  String get startRestore => '开始恢复';

  @override
  String get startExport => '开始导出';

  @override
  String get requestCancel => '请求取消';

  @override
  String get sourceMapping => '源和目标映射';

  @override
  String get nativeTool => '本机工具';

  @override
  String get defaultOmit => '省略 / 数据库默认值';

  @override
  String get overwriteNever => '不覆盖';

  @override
  String get overwriteExisting => '覆盖现有文件';

  @override
  String get planDetails => '计划详情';

  @override
  String get planMetricsNote => '估计值和实际测量值使用服务器字段名称。缺失的测量值不可用。';

  @override
  String get connected => '已连接';

  @override
  String get disconnected => '已断开';

  @override
  String get tables => '表';

  @override
  String get views => '视图';

  @override
  String get routines => '例程';

  @override
  String get expand => '展开';

  @override
  String get collapse => '折叠';

  @override
  String get databaseWorkbench => '数据库工作台';

  @override
  String get sidebar => '侧边栏';

  @override
  String get unchanged => '未更改';

  @override
  String get reviewDetails => '审查详情';

  @override
  String get generatedSql => '生成的 SQL';

  @override
  String get changeReverted => '已撤销待处理更改。请重新审查。';

  @override
  String get unknownBatch => '结果未知。批次可能已提交。切勿自动重放；请核查会话和恢复记录。';

  @override
  String get expiredChangeReview => '目标已更改或审查已过期。请重新审查。';

  @override
  String get applyCommitExplanation =>
      '应用并提交会启动并提交其自己的事务。来源控制台必须处于空闲状态并启用自动提交。请单独处理手动 SQL 事务。';

  @override
  String get newRow => '新行';

  @override
  String get original => '原始值';

  @override
  String get proposed => '建议值';

  @override
  String changeCounts(int inserts, int updates, int deletes) {
    return '插入 $inserts · 更新 $updates · 删除 $deletes';
  }

  @override
  String sourceRow(String row) {
    return '来源行 $row';
  }

  @override
  String get refreshing => '正在刷新…';

  @override
  String get refreshActivities => '刷新活动';

  @override
  String get explicitRefresh => '手动刷新';

  @override
  String get pollFiveSeconds => '每 5 秒轮询';

  @override
  String get cancelSelectedActivity => '取消选定活动';

  @override
  String get terminateSelectedSession => '终止选定会话';

  @override
  String get filterActivities => '筛选当前活动';

  @override
  String get blockedBy => '阻塞方：';

  @override
  String get delete => '删除';

  @override
  String get remove => '移除';

  @override
  String get up => '向上';

  @override
  String get search => '搜索';

  @override
  String get yes => '是';

  @override
  String get no => '否';

  @override
  String get clear => '清除';

  @override
  String get copy => '复制';

  @override
  String get insert => '插入';

  @override
  String get update => '更新';

  @override
  String get open => '打开';

  @override
  String get migrationEngineMismatch => '应用目标连接必须使用与比较快照相同的引擎。不支持跨引擎迁移。';

  @override
  String get metadataContextChanged => '检查上下文已更改。请显式刷新元数据。';

  @override
  String get newTableName => '新建表名称';

  @override
  String get routineIdentity => '例程的确切标识';

  @override
  String get objectColumnName => '对象 / 列名称';

  @override
  String get builtInType => '内置类型';

  @override
  String get sqlExpression => 'SQL 表达式（留空即移除）';

  @override
  String get newPropertyValue => '新的属性值';

  @override
  String get columnComment => '列注释';

  @override
  String get columnCollation => '列排序规则（留空使用服务器默认值）';

  @override
  String get addDesignedColumn => '向新表添加列';

  @override
  String get checkExpression => 'CHECK 表达式';

  @override
  String get referencedSchema => '引用的模式 / 数据库';

  @override
  String get generating => '正在生成…';

  @override
  String get generateReviewedDdl => '生成待审核 DDL';

  @override
  String get inspectCapturedDefinition => '检查已捕获的定义';

  @override
  String get capturedObject => '已捕获的对象';

  @override
  String get designReviewNote => '生成的更改用于审核。在执行已审核的操作之前，数据库内容保持不变。';

  @override
  String get columnMetadataUnavailable => '此范围的列元数据不可用；请先检查选定模式，再设计列列表。';

  @override
  String get ordinaryColumn => '普通列';

  @override
  String get columnWithDefault => '带默认值的列';

  @override
  String get identityColumn => '标识 / 自增';

  @override
  String get generatedColumn => '生成列';

  @override
  String get columnType => '列类型';

  @override
  String get nullableNotNull => '允许 NULL / NOT NULL';

  @override
  String get defaultExpression => '默认表达式';

  @override
  String get generatedExpression => '生成表达式';

  @override
  String get columnCollationProperty => '列排序规则';

  @override
  String get loggedUnlogged => '记录日志 / 不记录日志';

  @override
  String get tableComment => '表注释';

  @override
  String get storageEngine => '存储引擎';

  @override
  String get tableCollation => '表排序规则';

  @override
  String get rowFormat => '行格式';

  @override
  String get createOrReplace => '创建或替换';

  @override
  String get dropSelectedObject => '删除选定对象';

  @override
  String get addColumn => '添加列';

  @override
  String get editColumnProperties => '编辑列属性';

  @override
  String get tableProperties => '表属性';

  @override
  String get triggerDefinition => '触发器定义';

  @override
  String get createTable => '创建表';

  @override
  String get viewDefinition => '视图定义';

  @override
  String get routineDefinition => '例程定义';

  @override
  String get chooseExistingObject => '选择已有对象';

  @override
  String get nullable => '允许 NULL';

  @override
  String get removeIdentity => '移除标识';

  @override
  String get generatedAlways => '始终生成';

  @override
  String get generatedByDefault => '默认生成 / 自增';

  @override
  String get loggedTable => '记录日志的表';

  @override
  String get unloggedTable => '不记录日志的表';

  @override
  String get orderedPrimaryKeyColumns => '有序主键列';

  @override
  String get orderedColumns => '有序列';

  @override
  String get ordinaryIndex => '普通索引';

  @override
  String get uniqueIndex => '唯一索引';

  @override
  String get primaryKey => '主键';

  @override
  String get uniqueConstraint => '唯一约束';

  @override
  String get foreignKey => '外键';

  @override
  String get checkConstraint => 'CHECK 约束';

  @override
  String get immediateChecking => '立即检查';

  @override
  String get deferrableChecking => '可延迟检查';

  @override
  String get initiallyImmediate => '初始立即';

  @override
  String get initiallyDeferred => '初始延迟';

  @override
  String get referencedTable => '引用的表';

  @override
  String get orderedReferencedColumns => '按对应顺序排列的引用列';

  @override
  String get objectDefinitionEditor => '原生对象定义 SQL 编辑器';

  @override
  String get onDelete => '删除时';

  @override
  String get onUpdate => '更新时';

  @override
  String get stay => '留下';

  @override
  String get saveSqlClose => '保存 SQL 并关闭';

  @override
  String get discardSqlClose => '丢弃 SQL 并关闭';

  @override
  String get closeBusyData => '关闭 BusyData';

  @override
  String get saveDraftsClose => '保存草稿并关闭';

  @override
  String get closeWithoutRecovery => '不恢复直接关闭';

  @override
  String get recoveryFailed => '恢复失败';

  @override
  String get discardFailedSaveClose => '丢弃失败的保存并关闭';

  @override
  String get closeWithoutSavingRecovery => '不保存恢复数据直接关闭';

  @override
  String get disableSqlRecovery => '禁用 SQL 恢复';

  @override
  String get historyPrivacy => '历史隐私';

  @override
  String get enableSqlRetention => '启用 SQL 保留';

  @override
  String get disableSqlRetention => '禁用 SQL 保留';

  @override
  String get clearHistory => '清除历史';

  @override
  String get deleteHistoryEntry => '删除历史记录';

  @override
  String get deleteSelected => '删除所选';

  @override
  String get saveRetention => '保存保留设置';

  @override
  String get retentionDays => '保留天数';

  @override
  String get sqlTextRetained => '已保留 SQL 文本';

  @override
  String get sqlTextDisabled => 'SQL 文本已禁用';

  @override
  String get openHistoryQuery => '在新 SQL 标签页打开';

  @override
  String get caCertificateFile => 'CA 证书文件';

  @override
  String get clientCertificateFile => '客户端证书文件';

  @override
  String get clientKeyFile => '客户端密钥文件';

  @override
  String get directConnection => '直接连接';

  @override
  String get sshTunnel => 'SSH 隧道';

  @override
  String get sshHost => 'SSH 主机';

  @override
  String get sshPort => 'SSH 端口';

  @override
  String get sshUser => 'SSH 用户';

  @override
  String get reviewedKnownHosts => '已审查的 known_hosts 文件';

  @override
  String get reviewSshKey => '审查 SSH 主机密钥';

  @override
  String get changedSshKey => 'SSH 主机密钥已更改';

  @override
  String get verifyFingerprint => '信任之前，请独立验证此指纹。';

  @override
  String get selectedKeyPassword => '所选密钥或密码';

  @override
  String get selectedAgentIdentity => '所选 SSH 代理身份';

  @override
  String get selectedAgentSocket => '所选 Linux 代理套接字 / Windows 命名管道';

  @override
  String get selectedKeyFingerprint => '所选密钥指纹 · SHA256:…';

  @override
  String get selectedPrivateKey => '所选私钥（可选）';

  @override
  String get sshPassword => 'SSH 密码';

  @override
  String get keyPassphrase => '密钥口令';

  @override
  String get connectionTimeout => '连接超时 · 1–120 秒';

  @override
  String get sqlTimeout => 'SQL 执行/获取期限 · 1–3600 秒（0 = 60）';

  @override
  String get schemasEquivalent => '捕获的架构等效。';

  @override
  String get migrationComplete => '迁移涵盖捕获的受支持差异。';

  @override
  String get migrationPartial => '部分迁移；仍有不支持的差异。';

  @override
  String get differencesLimited => '差异显示有限。请审查完整的已保存快照和生成的 SQL。';

  @override
  String get absent => '不存在';

  @override
  String get definitionPreviewLimited => '定义预览有限；请使用原始快照查看完整依据。';

  @override
  String get migrationBatchNote => 'SQL 是按依赖顺序排列的单个批次。选择单个对象用于检查，不会选择要应用的语句。';

  @override
  String get unsupportedLabel => '不支持';

  @override
  String get differenceAdded => '已添加';

  @override
  String get differenceRemoved => '已移除';

  @override
  String get differenceChanged => '已更改';

  @override
  String get selectHistoryEntry => '选择历史记录';

  @override
  String get searchSqlTarget => '搜索 SQL 或目标';

  @override
  String get closeSqlTab => '关闭 SQL 标签页';

  @override
  String get historyMetadataRetained => '状态和目标元数据仍保留在历史中。';

  @override
  String get historyPreviewNote => '仅预览。在新 SQL 标签页打开以获取保留的文本。';

  @override
  String get selected => '已选择';

  @override
  String get authReviewNote =>
      '应用前请审查准确的用户或角色和目标。凭据绝不会放入 SQL 文档或历史。现有连接和保存的密码保持独立。';

  @override
  String get createLogin => '创建登录账户';

  @override
  String get createRole => '创建不可登录角色';

  @override
  String get setPassword => '设置密码';

  @override
  String get preventLogin => '阻止新登录';

  @override
  String get allowLogin => '允许新登录';

  @override
  String get dropPrincipal => '删除用户或角色';

  @override
  String get principalName => '准确的用户或角色名称';

  @override
  String get accountHost => '准确的账户主机（通配符会扩大登录范围）';

  @override
  String get newPassword => '新密码';

  @override
  String get repeatPassword => '重复新密码';

  @override
  String get reviewAccount => '审查账户操作';

  @override
  String get passwordsMismatch => '请两次输入相同的非空密码';

  @override
  String get accountSubmitFailed => '无法提交账户操作。请检查目标、认证策略和数据库权限。';

  @override
  String get privilegeReviewNote => '检查直接授予的权限；生成的 SQL 仍需要执行审查。';

  @override
  String get inspectionLimited => '每节最多 500 行。请缩小搜索范围；空节并不能证明没有有效访问权限。';

  @override
  String get findPrincipal => '查找用户 / 角色名称';

  @override
  String get searchPrincipals => '搜索用户和角色';

  @override
  String get choosePrincipal => '选择用户或角色';

  @override
  String get inspectGrants => '检查所选权限';

  @override
  String get tablePrivileges => '表 / 视图权限';

  @override
  String get schemaPrivileges => '模式权限';

  @override
  String get databasePrivileges => '数据库权限';

  @override
  String get roleMembership => '角色成员关系';

  @override
  String get defaultRole => '默认角色激活';

  @override
  String get chooseGrantRole => '选择要授予 / 撤销的角色';

  @override
  String get tableView => '表 / 视图';

  @override
  String get explicitPrivileges => '明确权限（逗号分隔）';

  @override
  String get setDefaultRole => '设置所选默认角色';

  @override
  String get clearDefaultRole => '清除默认角色';

  @override
  String get grantAccess => '授予访问';

  @override
  String get revokeAccess => '撤销访问';

  @override
  String get withoutDelegation => '不委派';

  @override
  String get allowDelegation => '允许接收者授予他人';

  @override
  String get readonlyChanges => '此配置为只读。更改需要明确可写的会话。';

  @override
  String get createPrincipal => '创建用户 / 角色';

  @override
  String get manageAuthentication => '管理所选认证';

  @override
  String get openPrivilegeSql => '打开权限 SQL 供审查';

  @override
  String get inspectPrincipalFirst => '拟定更改前请检查所选用户或角色';

  @override
  String get accountAuthentication => '账户认证';

  @override
  String get schema => '模式';

  @override
  String get available => '可用';

  @override
  String get availableEmpty => '可用 · 数据为空';

  @override
  String get limitedVisibility => '可见性或范围有限';

  @override
  String get permissionDenied => '权限被拒绝';

  @override
  String get unavailable => '不可用';

  @override
  String get profileDisabled => '由配置禁用';

  @override
  String get unknownState => '未知';

  @override
  String get inspecting => '正在检查…';

  @override
  String get refreshCapabilities => '刷新功能';

  @override
  String get staleRefresh => '已过期 · 连接后刷新';

  @override
  String get staleContext => '已过期 · 连接或上下文更改后刷新';

  @override
  String get partialTreeLimit => '部分 · 已达到树上限；请缩小数据库对象搜索范围';

  @override
  String get schemaComparison => '模式比较';

  @override
  String get searchTable => '搜索表';

  @override
  String get focusObject => '聚焦';

  @override
  String get exportSvg => '导出 SVG';

  @override
  String get exportPng => '导出 PNG';

  @override
  String get diagramNotes => '图表备注（包含在 SVG 中）';

  @override
  String get openNotes => '打开备注';

  @override
  String get saveNotes => '保存备注';

  @override
  String get newSnippet => '新建片段';

  @override
  String get snippetName => '片段名称';

  @override
  String get saveSnippet => '保存片段';

  @override
  String get deleteSnippet => '删除已保存片段';

  @override
  String get insertSnippet => '插入 SQL 文档';

  @override
  String get snippetEditor => 'SQL 片段编辑器';

  @override
  String get snippetsNote => '将已保存的本地 SQL 插入所选文档，可撤销。执行仍需明确操作。';

  @override
  String get level => '级别';

  @override
  String get expanded => '已展开';

  @override
  String get collapsed => '已折叠';

  @override
  String get treeLevel => '级别';

  @override
  String get retainedView => '保留视图';

  @override
  String get tableQuerySnapshot => '表查询快照';

  @override
  String get originalResultNote => '原始保留结果；分页和检查不会执行 SQL';

  @override
  String get tableFilterNote => '应用会提交新的已审查数据库查询。旧快照仍然保留。';

  @override
  String get retainedFilterNote => '固定快照内所有已获取行。不会重新运行 SQL。保留值排序可能与数据库排序规则不同。';

  @override
  String get retainedRowNote => '请选择已获取结果中的行。不会重新运行 SQL。';

  @override
  String get copyLimitNote => '复制最多 10,000 个单元格；更大范围请导出保留数据。';

  @override
  String get inlineValueLimit => '单元格编辑支持 8KiB 值';

  @override
  String get editContextChanged => '源会话或编辑上下文已更改；暂存前请检查或刷新评估';

  @override
  String get editAssessmentUnavailable => '无法评估可编辑性；会话空闲后请刷新评估';

  @override
  String get rowChangeReverted => '待处理行更改已还原；数据库未变';

  @override
  String get sqlCopyRequiresMetadata => 'SQL 复制需要后端及其保留类型元数据。';

  @override
  String get exportFullValue => '导出完整保留值';

  @override
  String valueExportReview(String bytes, String path) {
    return '将 $bytes 字节保存到 $path？将替换现有内容。不会重新运行 SQL。';
  }

  @override
  String get goToRetainedRow => '转到保留行';

  @override
  String get row => '行';

  @override
  String get go => '转到';

  @override
  String get retryRows => '重试保留行';

  @override
  String get previousRows => '上一批行';

  @override
  String get nextRows => '下一批行';

  @override
  String get firstWindow => '首个保留窗口';

  @override
  String get lastWindow => '最后获取的窗口';

  @override
  String get setNull => '设置 NULL';

  @override
  String copyFormat(String format) {
    return '复制 $format';
  }

  @override
  String get textValue => '文本';

  @override
  String get sqlValues => 'SQL 值';

  @override
  String get rowSelection => '行选择';

  @override
  String selectRow(String row) {
    return '选择行 $row';
  }

  @override
  String columnHeader(String column) {
    return '列 $column';
  }

  @override
  String get pendingChange => '待处理更改';

  @override
  String get readonlyCell => '只读单元格';

  @override
  String get editableCell => '可编辑单元格';

  @override
  String get loadValueFirst => '请先加载此保留值';

  @override
  String get editUnavailable => '不可编辑';

  @override
  String get editCell => '编辑单元格';

  @override
  String get unsupportedEditValue => '此保留值仅支持检查';

  @override
  String bytesCount(String bytes) {
    return '$bytes 字节';
  }

  @override
  String get problems => '问题';

  @override
  String get ownedSessions => '所属会话';

  @override
  String get noProblems => '没有记录的问题';

  @override
  String get duplicateConnection => '复制连接';

  @override
  String get deleteConnection => '删除连接';

  @override
  String deleteConnectionReview(String name) {
    return '删除 $name？现有物理会话保持原始设置。';
  }

  @override
  String get unresolvedSessions => '未解决会话';

  @override
  String get disconnectSessionNote =>
      '请先处理活动作业和事务。断开会影响此物理会话的所有客户端；不会提交事务或重放 SQL。未知结果仍然未知。';

  @override
  String get transferSettingsChanged => '设置已更改；请重新审查';

  @override
  String get transferReviewReady => '审查就绪；开始前核对目标、范围、映射和文件';

  @override
  String get sourcePreviewNotice => '源预览；未导入数据库行';

  @override
  String get transferRequiresReview => '请先审查此准确传输';

  @override
  String get transferSubmittedNotice => '已提交；取消不会撤销已确认提交或已发布文件';

  @override
  String get sqlExportExecutionNote => '新的已审查 SQL 执行';

  @override
  String get retainedExportSnapshotNote => '已获取快照；不会执行 SQL';

  @override
  String get restorePartialCommitNote => '还原可能部分提交。取消不会撤销还原。';

  @override
  String get sourcePreviewLimit => '源预览；最多 20 行';

  @override
  String get importBatchSafetyNote => '错误或取消会保留此前的批次提交。发送前再次验证源哈希和所选不可变材料。';

  @override
  String get nullMarkerLiteralNote => '无引号 NULL 标记；带引号时为文字文本';

  @override
  String immutableSourceHash(String hash) {
    return '不可变源 SHA-256：$hash';
  }

  @override
  String sourceColumnLabel(String column) {
    return '源列 $column';
  }

  @override
  String previewRowLabel(String row, String column, String value) {
    return '预览行 $row，$column：$value';
  }

  @override
  String get transferCancellationNotice => '已请求取消；等待确认';

  @override
  String transferProgress(String processed, String committed, String rejected) {
    return '$processed 已处理 · $committed 已提交 · $rejected 已拒绝';
  }

  @override
  String get importAtomicPolicy => '所有行在一个事务中';

  @override
  String get importBatchPolicy => '按批次提交；遇错停止';

  @override
  String get importSkipPolicy => '跳过无效行；按批次提交';

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
    return '确认/连接：$operations\n未保存文档：$documents\n正在保存：$saves\n待处理编辑：$edits\n活动作业：$jobs\n需清理事务：$transactions\n未知操作结果：$unknown\n不确定会话：$sessions';
  }

  @override
  String get closeDraftSaved => 'SQL 草稿将保存到本地。';

  @override
  String get closeDraftLost => '恢复已关闭；未保存的 SQL 和对象设计将丢失。';

  @override
  String get closeDesignRecovery => '对象设计使用私密有界恢复。重新打开后请明确连接并检查元数据。';

  @override
  String get closeCleanupReview =>
      '关闭最后的会话所有者会请求取消、回滚已确认事务并断开。未知结果仍然未知；关闭绝不会提交或重放 SQL。';

  @override
  String get closeSharedSession => '其他客户端保留共享物理会话。';

  @override
  String get closeStagedRecovery => '待处理更改需要确认私密恢复、明确重新连接和新的审查。';

  @override
  String get closeRecoveryLoss => '未能保存文档和布局。关闭可能丢失 SQL 和更改；现有文件及恢复数据仍会保留。';

  @override
  String get closeWaitNotice => '关闭前请等待操作确认和连接清理。';

  @override
  String get saveFailedNotice => 'SQL 保存失败。请保留已修改 SQL 或明确丢弃。';

  @override
  String get closeCleanupFailed => '后端清理失败；BusyData 保持打开。';

  @override
  String get closeBackendUnverified => '后端状态未验证；可能仍有待处理工作。';

  @override
  String historyRetainSqlReview(String days) {
    return 'SQL 可能包含秘密。保存文本 $days 天？';
  }

  @override
  String get historyStopSqlReview => '停止保存 SQL 并从现有历史中删除？';

  @override
  String get historyClearReview => '清除所有历史？活动作业结束时可能记录结果。';

  @override
  String get historyDeleteReview => '删除选中的历史条目？';

  @override
  String get historyRetentionRange => '保留时间必须为 1–3650 天';

  @override
  String get enableSqlHistory => '启用 SQL 历史';

  @override
  String get stopSqlHistory => '停止保留 SQL';

  @override
  String get recoveryDiscardReview => '丢弃恢复记录？请先核对未知结果；丢弃不会撤销已提交更改。';

  @override
  String closeSqlSummary(String unsaved, String edits, String jobs) {
    return '未保存 SQL：$unsaved\n待处理更改：$edits\n活动作业：$jobs';
  }

  @override
  String get recoveryStayOpen => '恢复失败。BusyData 保持打开；未保存的工作仍被保留。';

  @override
  String get commitUncertaintyNote => '网络故障可能使提交结果未知。绝不要自动重试。';

  @override
  String get closeObjectDesignDiscard => '将丢弃未保存的对象设计字段。请先生成并保存 SQL 以保留设计。';

  @override
  String get savePrivateDrafts => '保存私密恢复草稿';

  @override
  String get noPrivateDrafts => '不保存恢复草稿';

  @override
  String shortcutField(String command) {
    return '$command 快捷键';
  }

  @override
  String get shortcutInvalid => '请使用未分配给其他操作的有效快捷键。F6 和 Shift+F6 已保留。';

  @override
  String get disableRecoveryReview =>
      '删除本地 SQL、设计及暂存更改的恢复？未保存工作保持打开，但崩溃可能丢失。请先核对未知结果。';

  @override
  String get preferencesSaved => '设置已保存';

  @override
  String get sharingSessionReview =>
      '此查询与列出的客户端共享所命名的物理会话、事务、临时对象及设置。关闭一个客户端会保留其他客户端。';

  @override
  String get recoveryReconcileFirst => '关闭恢复前请核对正在应用或未知的更改。仅通过明确的单独审查丢弃恢复记录。';

  @override
  String get enterSearchText => '输入搜索文本';

  @override
  String get noSearchMatches => '无匹配项';

  @override
  String searchMatchCount(String position, String total) {
    return '第 $position 项，共 $total 项';
  }

  @override
  String get formatSqlChanged => 'SQL 或目标已更改。原始 SQL 已保留；请重新请求格式预览。';

  @override
  String get formatSqlUnavailable => '语法不完整、不受支持或超出分析限制，无法格式化。原始 SQL 已保留。';

  @override
  String get stageChange => '暂存更改';

  @override
  String pendingChangesCount(String count) {
    return '$count 项待处理更改；经审查应用前数据库保持不变。';
  }

  @override
  String discardChangesCount(String count) {
    return '丢弃 $count 项待处理更改？不会提交数据库操作。';
  }

  @override
  String get recoveryNoExecution => '恢复不会连接、运行源 SQL、恢复事务或重放更改。未知及已提交记录无法再次应用。';

  @override
  String get recoveredDesign => '设计已恢复。请明确连接并检查当前元数据后再生成审查。恢复未获取 SQL 或元数据。';

  @override
  String get retainedUnavailable => '保留数据不可用。已保存的 SQL 和私密恢复仍在本地。';

  @override
  String get activityFingerprintNote => '提交前会重新验证所选活动的指纹。写入结果可能未知。';

  @override
  String replaceFileReview(String path) {
    return '替换已审查的文件 $path？目标更改需要重新审查。';
  }

  @override
  String get diagramPngSaved => '图表 PNG 已保存。长备注最多显示六行。';

  @override
  String get editTargetChanged => '编辑目标已更改。暂存前请重新打开行编辑器。';

  @override
  String affectedRowCount(String count) {
    return '受影响的行数：$count';
  }

  @override
  String get zoomIn => '放大';

  @override
  String get zoomOut => '缩小';

  @override
  String get resetView => '重置视图';

  @override
  String get diagramKeys => '方向键平移；+ 和 - 缩放；Home 重置视图。';

  @override
  String get explorerConnected => '资源管理器已连接';

  @override
  String get explorerDisconnected => '资源管理器未连接';

  @override
  String querySessionCount(String count) {
    return '查询会话 $count';
  }

  @override
  String get metadataColumn => '列';

  @override
  String get metadataPosition => '位置';

  @override
  String get metadataUnique => '唯一';

  @override
  String get metadataJdbcType => 'JDBC 类型';

  @override
  String get metadataAutoIncrement => '自动递增';

  @override
  String get metadataReferencedColumn => '引用列';

  @override
  String get metadataComment => '注释';

  @override
  String get metadataType => '类型';

  @override
  String get metadataEvent => '事件';

  @override
  String get metadataSpecificName => '原生特定标识符';

  @override
  String get metadataOptions => '选项';

  @override
  String get metadataInheritance => '继承';

  @override
  String get metadataDefinitionCaptured => '已捕获的原生定义';

  @override
  String get metadataDefinitionUnavailable => '捕获的元数据中无法提供定义';

  @override
  String get metadataDefinitionUnsupported => '捕获的对象没有受支持的原生定义';

  @override
  String get connections => '连接';

  @override
  String get noConnections => '尚无连接';

  @override
  String get startTitle => '连接数据库';

  @override
  String get startDescription =>
      '连接 PostgreSQL、MySQL 或 MariaDB，浏览对象、管理数据并运行查询。';

  @override
  String get savedStartTitle => '选择连接';

  @override
  String get savedStartDescription => '在数据库资源管理器中连接已保存的连接，浏览对象并运行查询。';

  @override
  String get noConnection => '无连接';

  @override
  String queryTitle(int number) {
    return '查询 $number';
  }

  @override
  String get sessionMenu => '会话';

  @override
  String get noFilterMatches => '没有匹配的连接或已加载对象';

  @override
  String get activityState => '状态';

  @override
  String get activityWait => '等待';

  @override
  String get generalSettings => '常规';

  @override
  String get optionsSettings => '选项';

  @override
  String get host => '主机';

  @override
  String get databaseSystem => '数据库系统';

  @override
  String get passwordStorage => '密码存储';

  @override
  String get environmentLabel => '环境';

  @override
  String get readOnlySettings => '只读策略';

  @override
  String get tlsPolicy => 'TLS 策略';

  @override
  String get sshConnection => 'SSH 连接';

  @override
  String get sshAuthentication => 'SSH 身份验证';

  @override
  String get connectionTestAction => '测试连接';

  @override
  String get details => '详细信息';

  @override
  String get copyDetails => '复制详细信息';

  @override
  String get retry => '重试';

  @override
  String get filterCellValue => '按此值筛选';

  @override
  String get connectsWhenRun => '运行时连接';

  @override
  String get connectionSaving => '保存…';

  @override
  String get connectionConnecting => '连接…';

  @override
  String get connectionCancelling => '取消…';

  @override
  String get connectionSettingsChanged => '设置已更改。请重新测试此版本。';

  @override
  String get connectionTestChanged => '设置已更改。请重新测试此版本。';

  @override
  String get connectionRequired => '必填';

  @override
  String get connectionCorrectFields => '请检查标出的设置。';

  @override
  String get connectionHostname => '主机 · 请检查标出的设置。';

  @override
  String get connectionSshHostname => 'SSH · 主机 · 请检查标出的设置。';

  @override
  String get connectionMaxLength => '名称 ≤ 256';

  @override
  String get connectionTlsHelp => 'TLS · 主机 · SSH/SSL. 请检查标出的设置。';

  @override
  String get connectionTlsReview => 'TLS · 主机 · SSH/SSL. 请检查标出的设置。';

  @override
  String get connectionStorageUnavailable => '密码存储: 不可用. 密码 · 从不.';

  @override
  String get connectionHostReviewed => '主机 · 信任仅适用于此配置和此精确端点。';

  @override
  String get connectionSshReviewing => 'SSH · 审查 SSH 主机密钥…';

  @override
  String get connectionFailureAuthentication => '失败 · 身份验证 · 常规. 请检查标出的设置。';

  @override
  String get connectionFailureTls => '失败 · TLS · SSH/SSL. 请检查标出的设置。';

  @override
  String get connectionFailureSshKey => '失败 · 审查 SSH 主机密钥. 请检查标出的设置。';

  @override
  String get connectionFailureEndpoint => '失败 · 主机 · 端口. 请检查标出的设置。';

  @override
  String get connectionFailureCancelled => '已取消';

  @override
  String get connectionFailureSettings => '失败 · 常规. 请检查标出的设置。';

  @override
  String get connectionFailureAccess => '失败 · 表 / 视图权限. 请检查标出的设置。';

  @override
  String get connectionFailureUnavailable => '失败 · 主机 · TLS · SSH. 请检查标出的设置。';

  @override
  String get connectionFailureTimeout => '失败 · 连接超时 · 1–120 秒. 请检查标出的设置。';

  @override
  String get connectionFailureUnknown => '失败 · 常规 · TLS · SSH. 请检查标出的设置。';

  @override
  String connectionNumber(int min, int max) {
    return '请输入 $min 到 $max 之间的整数';
  }

  @override
  String connectionSavedFailure(String name) {
    return '连接已保存：$name。连接尝试失败。 ';
  }

  @override
  String get backendBusy => '后端忙碌。请等待当前请求完成，然后重试。';

  @override
  String rpcRequestUnconfirmed(String code) {
    return '请求未获确认（RPC $code）。';
  }

  @override
  String get operationUnconfirmed => '无法完成操作。';

  @override
  String get connectionFailureTlsMaterial =>
      'TLS 材料不可用或无效。请在 SSH/SSL 中检查信任来源和客户端密钥。';

  @override
  String get managerTitle => '数据源和驱动程序';

  @override
  String get sourceListTitle => '数据源';

  @override
  String get driverLabel => '驱动程序';

  @override
  String get connectionTypeLabel => '连接类型';

  @override
  String get defaultTcp => '默认 (TCP)';

  @override
  String get authenticationLabel => '身份验证';

  @override
  String get userPasswordAuth => '用户和密码';

  @override
  String get neverStorage => '从不';

  @override
  String get initialDatabaseLabel => '初始数据库';

  @override
  String get useSshTunnel => '使用 SSH 隧道';

  @override
  String get sshConfigurationLabel => 'SSH 配置';

  @override
  String get createSshConfig => '<创建配置>';

  @override
  String get copySshSettings => '复制 SSH 设置';

  @override
  String get localPortLabel => '本地端口';

  @override
  String get dynamicPortLabel => '<动态>';

  @override
  String get useSsl => '使用 SSL';

  @override
  String get useTruststore => '使用信任库';

  @override
  String get clientKeyPasswordLabel => '客户端密钥密码';

  @override
  String get modeLabel => '模式';

  @override
  String get requireTls => '要求';

  @override
  String get verifyCa => '验证 CA';

  @override
  String get fullVerification => '完全验证';

  @override
  String get connectionSection => '连接';

  @override
  String get configurationApplied => '配置已应用';

  @override
  String get noOtherSshConfig => '其他数据源没有 SSH 配置。';

  @override
  String get generatedUrlHelp => '生成的只读 JDBC 地址。';

  @override
  String get tlsDriverDefaultHelp => 'SSL 尚未配置；使用随附驱动程序的默认设置。';

  @override
  String get tlsClientKeyHelp => 'PEM 密钥：PKCS#8 或 OpenSSL；支持加密或未加密密钥。';

  @override
  String get legacyMariaTrustHelp => '保留现有驱动程序验证。选择信任来源以明确配置根证书。';

  @override
  String get metadataStartValue => '起始值';

  @override
  String get metadataMinimumValue => '最小值';

  @override
  String get metadataMaximumValue => '最大值';

  @override
  String get metadataIncrement => '增量';

  @override
  String get metadataCycle => '循环';

  @override
  String get metadataCacheSize => '缓存大小';

  @override
  String get metadataLastValue => '最后值';

  @override
  String get sequences => '序列';

  @override
  String get namespaceSelection => '选择命名空间';

  @override
  String get namespaceSelectionNotice => '选择控制元数据内省。查询控制台保留其执行上下文。';

  @override
  String get allNamespaces => '所有命名空间';

  @override
  String get defaultNamespace => '默认';

  @override
  String get namespacePattern => '名称模式（正则表达式）';

  @override
  String namespaceCount(int selected, int known) {
    return '$known 中的 $selected';
  }

  @override
  String get previousPage => '上一页';

  @override
  String get patternRejected => '模式无效或超出工作限制。保留先前的选择。';

  @override
  String get namespaceNotSelected => '未选择此命名空间进行内省';

  @override
  String get newMenu => '新建';

  @override
  String get queryConsoles => '查询控制台';

  @override
  String get viewOptions => '视图选项';

  @override
  String get quickDocumentation => '快速文档';

  @override
  String get showEmptyGroups => '显示空分组';

  @override
  String get speedSearch => '快速搜索';

  @override
  String get speedSearchScope => '仅搜索已展开且已加载的节点。';

  @override
  String get newSourceFolder => '新建数据源文件夹';

  @override
  String get renameSourceFolder => '重命名文件夹';

  @override
  String get moveToFolder => '移动到文件夹';

  @override
  String get moveUp => '上移';

  @override
  String get moveDown => '下移';

  @override
  String get folderMustBeEmpty => '删除此文件夹前，请移出其中的数据源和文件夹。';

  @override
  String get newVirtualView => '新建虚拟视图';

  @override
  String get editVirtualDefinition => '编辑本地定义';

  @override
  String get unboundVirtualView => '未绑定的虚拟视图';

  @override
  String get localVirtualViewNotice =>
      '本地 SQL 定义。保存不会执行 SQL 或创建服务器视图。运行使用常规 SQL 审核和独立控制台。';

  @override
  String get rebindVirtualView => '将本地定义绑定到此处';

  @override
  String get sourceFolderName => '文件夹名称';

  @override
  String get sourceFolderPathNotice => '使用 / 创建嵌套文件夹。';

  @override
  String get topLevel => '顶层';

  @override
  String get virtualViewName => '虚拟视图名称';

  @override
  String get virtualViewSql => '虚拟视图 SQL 定义';

  @override
  String get virtualViews => '虚拟视图';

  @override
  String get revealInExplorer => '在数据库资源管理器中显示';

  @override
  String get objectNotFound => '在此命名空间中未找到对象。请刷新元数据或检查权限。';

  @override
  String get objectHiddenByFilter => '当前视图筛选器隐藏了此对象。';

  @override
  String get revealFilterNotice => '对象查找缩小了此页范围，因此省略整个分组的总数。';

  @override
  String get clearObjectFilter => '清除对象查找';

  @override
  String get compareStructure => '比较结构';

  @override
  String get selectTwoCompatibleObjects => '按住 Ctrl 单击选择两个兼容的表。';

  @override
  String get scopedComparisonRestriction =>
      '限定范围的比较要求普通表具有相同的原生名称、模式和引擎。不支持其他类型或重命名匹配。';

  @override
  String get groupNamespaces => '分组显示数据库和模式';

  @override
  String get groupSchemaObjects => '分组显示模式对象';

  @override
  String get groupTableElements => '分组显示表元素';

  @override
  String get sortAlphabetically => '按字母顺序排序';

  @override
  String get showVirtualObjects => '显示虚拟对象';

  @override
  String get showObjectComments => '显示对象注释';

  @override
  String get objectTypeFilter => '对象类型筛选器';

  @override
  String get partitionedTable => '分区表';

  @override
  String get foreignTable => '外部表';

  @override
  String get materializedView => '物化视图';

  @override
  String get functionObject => '函数';

  @override
  String get procedureObject => '存储过程';

  @override
  String get sqlSymbolUnavailable =>
      '无法安全解析光标处的持久对象。请连接此控制台，并使用字面量和注释之外的表或视图引用。';

  @override
  String get sqlSymbolAmbiguous => 'SQL 对象引用不明确。请限定其命名空间或选择准确的数据库对象。';

  @override
  String get deactivateSource => '停用数据源';

  @override
  String get functions => '函数';

  @override
  String get procedures => '存储过程';

  @override
  String get separateProceduresFunctions => '分开显示存储过程与函数';

  @override
  String get renameVirtualView => '重命名虚拟视图';

  @override
  String get metadataPersistentScope => '仅显示持久对象；临时对象和会话本地对象仍在控制台导航中。';

  @override
  String get metadataSessionScope => '仅显示持久对象；执行后请刷新控制台本地对象。';

  @override
  String get metadataLimitScope => '已达到元数据限制。请缩小对象范围。';

  @override
  String get completeColumnMetadataRequired => '导入或暂存更改前需要完整的列元数据。';

  @override
  String resizeColumn(String name) {
    return '调整列 $name 的宽度';
  }

  @override
  String get keyboardShortcutsHeading => '键盘快捷键';

  @override
  String sqlEditorLabel(String title) {
    return 'SQL 编辑器 $title';
  }

  @override
  String get editorResultsDivider => '编辑器与结果分隔线';

  @override
  String editorExtent(String percent) {
    return '编辑器占 $percent 百分比';
  }

  @override
  String get largerEditor => '扩大编辑器';

  @override
  String get smallerEditor => '缩小编辑器';

  @override
  String get explorerWidthDivider => '资源管理器宽度分隔线';

  @override
  String get widerExplorer => '加宽资源管理器';

  @override
  String get narrowerExplorer => '缩窄资源管理器';

  @override
  String explorerExtent(String width) {
    return '宽 $width 像素';
  }

  @override
  String planTextPage(String start, String end, String total) {
    return '第 $start–$end 个，共 $total 个 UTF-16 单元';
  }

  @override
  String get dropDesignedColumn => '删除列';

  @override
  String get liveCatalogLabel => '当前目录';

  @override
  String get liveSchemaLabel => '当前模式';

  @override
  String get searchPathLabel => '搜索路径';

  @override
  String get physicalSessionLabel => '物理会话';

  @override
  String queryTimeoutDetail(String seconds, String rows) {
    return '超时：$seconds 秒 · 行数限制：$rows';
  }

  @override
  String get saveFailedCloseTitle => 'SQL 保存失败 · 关闭 BusyData';

  @override
  String get createSection => '创建';

  @override
  String get newConnectionDescription => '配置数据库连接';

  @override
  String get newQueryDescription => '在新查询中编写 SQL';

  @override
  String get openSqlDescription => '打开现有 SQL 文档';

  @override
  String get searchNoResults => '没有匹配的操作';

  @override
  String get actionsCategory => '操作';

  @override
  String get privateRecoveryCategory => '私密恢复';

  @override
  String get shortcutRecordHelp => '请按快捷键。Escape 取消。F6 和 Shift+F6 保留用于面板导航。';

  @override
  String get rowLimitInvalid => '请输入 1 到 1,000,000 之间的行数限制。';

  @override
  String get errorPolicy => '执行出错时';

  @override
  String get tlsEncrypted => '已加密';

  @override
  String get tlsUnencrypted => '未加密';

  @override
  String get tlsUnobserved => '未观察到';

  @override
  String get encryptionVerificationNote => '加密并不证明已验证证书或主机名。';

  @override
  String get uniqueDesignedColumnName => '请使用唯一的列名；新建表最多支持 128 列';

  @override
  String activityBlockerUnavailable(String id) {
    return '阻塞会话 $id 已不可见；请刷新并检查数据库权限';
  }

  @override
  String get sshChangedKeyReview => '替换此配置的绑定前，请独立验证更改后的密钥。';

  @override
  String get sshProfileTrustBinding => '信任仅适用于此配置和此精确端点。';

  @override
  String get databaseTlsEvidence => 'TLS · 数据库系统';

  @override
  String get sshAlgorithmLabel => 'SSH · 类型';

  @override
  String get sshFingerprintLabel => 'SHA-256';

  @override
  String get sshPreviousFingerprintLabel => '上一项 · SHA-256';

  @override
  String get sshReviewedLabel => '审查 SSH 主机密钥';

  @override
  String get shortcutRecordAction => '录制快捷键';

  @override
  String get fileFormatLabel => '文件格式';

  @override
  String get encodingLabel => '编码';

  @override
  String get importPolicyLabel => '导入策略';

  @override
  String get mainMenu => '主菜单';

  @override
  String get activityReplyTooLarge => '活动响应超出检查器限制。';

  @override
  String get activityListLimited => '列表受限；请使用明确的 SQL 检查更小范围的目标。';

  @override
  String get activitySelectionChanged => '所选活动已结束或发生变化。请先选择其当前标识，再审查操作。';

  @override
  String connectionSavedDraftChanged(String name) {
    return '保存时连接字段已更改；配置已保存：$name。连接前请检查当前值。';
  }

  @override
  String get sshReviewTargetChanged => 'SSH 审核目标已更改；请重新审核';

  @override
  String get appearance => '外观';

  @override
  String get theme => '主题';

  @override
  String get systemTheme => '系统';

  @override
  String get lightTheme => '浅色';

  @override
  String get darkTheme => '深色';

  @override
  String get appLanguage => '语言';

  @override
  String get systemLanguage => '系统';

  @override
  String get cut => '剪切';

  @override
  String get paste => '粘贴';

  @override
  String get selectAll => '全选';

  @override
  String get noSelection => '没有可用文本';

  @override
  String get clipboardEmpty => '剪贴板中没有文本';

  @override
  String get settingsDraftNotice => '执行和私密恢复的更改尚未保存。';

  @override
  String get documentsMenu => '文档';

  @override
  String get currentSql => '当前 SQL';

  @override
  String get searchActionsHint => '搜索操作…';

  @override
  String get searchCurrentSqlHint => 'Search current SQL…';

  @override
  String get searchObjectsHint => 'Search database objects…';

  @override
  String get searchHistoryHint => 'Search query history…';

  @override
  String get metadataAttributes => '属性';

  @override
  String get metadataSelectionUnavailable => '选择一个项目以检查其捕获的属性。先前的选择不可用。';

  @override
  String get secureStorage => '系统安全存储';

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
  String get metadataCacheWriteUnavailable => '无法保存缓存。当前元数据仍然可用。';

  @override
  String get metadataCacheRebuiltVersion => '已为当前版本重建';

  @override
  String get metadataCacheRebuiltCorrupt => '发生缓存错误后已重建';

  @override
  String get editSessionBusy => '此会话正忙。请等待当前工作完成，然后请求重新评估可编辑性。';

  @override
  String get editIdentityRequired => '编辑前，请选择完整的主键或不允许 NULL 的唯一标识。';

  @override
  String get editColumnsReadOnly => '所有投影列均为生成列或只读列。';

  @override
  String get editResultNotReady => '请等待此保留结果完成，然后请求重新评估可编辑性。';

  @override
  String get editProjectionUnsupported => '编辑要求直接从一个基表执行 SELECT，且每个基表列仅投影一次。';

  @override
  String get sqlInspectionDuplicateUsingColumn => 'JOIN USING 列重复';

  @override
  String get sqlInspectionUnresolvedUsingColumn => '某个操作数中缺少 JOIN USING 列';

  @override
  String get sqlInspectionAmbiguousUsingColumn => 'JOIN 公共列不明确';

  @override
  String get sqlInspectionOutputColumnCount => '声明的输出列数不匹配';

  @override
  String get sqlInspectionAmbiguousOverload => '例程重载不明确';

  @override
  String get sqlInspectionBooleanType => '布尔表达式类型无效';

  @override
  String get sqlInspectionOperatorTypes => '运算符的操作数类型不兼容';

  @override
  String get sqlInspectionArrayTypes => '数组元素类型不兼容';

  @override
  String get sqlInspectionCaseConditionType => 'CASE 条件类型不兼容';

  @override
  String get sqlInspectionCaseResultTypes => 'CASE 结果类型不兼容';

  @override
  String get sqlInspectionCoalesceTypes => 'COALESCE 参数类型不兼容';

  @override
  String get sqlInspectionSetColumnCount => '集合运算的列数不匹配';

  @override
  String get sqlInspectionSetTypes => '集合运算的结果类型不兼容';

  @override
  String get sqlInspectionRecursiveCteType => '递归 CTE 类型不匹配';
}

/// The translations for Chinese, using the Han script (`zh_Hans`).
class AppLocalizationsZhHans extends AppLocalizationsZh {
  AppLocalizationsZhHans() : super('zh_Hans');

  @override
  String get cancel => '取消';

  @override
  String get windowMinimize => '最小化';

  @override
  String get windowMaximize => '最大化';

  @override
  String get windowRestore => '还原';

  @override
  String get databaseExplorer => '数据库资源管理器';

  @override
  String get databases => '数据库';

  @override
  String get newConnection => '新建连接';

  @override
  String get filterTree => '筛选连接和对象';

  @override
  String get treeFilterScope => '筛选已加载的树对象';

  @override
  String get searchObjects => '搜索数据库对象';

  @override
  String get fileMenu => '文件';

  @override
  String get editMenu => '编辑';

  @override
  String get viewMenu => '视图';

  @override
  String get connectionMenu => '连接';

  @override
  String get objectMenu => '对象';

  @override
  String get runMenu => '执行选项';

  @override
  String get commands => '命令';

  @override
  String get findCommand => '查找命令';

  @override
  String get newSql => '新建查询';

  @override
  String get openSql => '打开 SQL';

  @override
  String get openSqlFile => '打开 SQL 文件';

  @override
  String get saveSql => '保存 SQL';

  @override
  String get closeTab => '关闭标签页';

  @override
  String get openWorkspace => '打开工作区';

  @override
  String get saveWorkspace => '保存工作区';

  @override
  String get settings => '设置';

  @override
  String get findText => '查找';

  @override
  String get replaceText => '替换';

  @override
  String get formatSql => '格式化 SQL';

  @override
  String get lineComments => '切换行注释';

  @override
  String get snippets => 'SQL 代码片段';

  @override
  String get run => '运行';

  @override
  String get runStatement => '运行当前语句';

  @override
  String get runSelection => '运行所选内容';

  @override
  String get runScript => '运行脚本';

  @override
  String get explain => '执行计划';

  @override
  String get explainAnalyze => '执行并分析计划';

  @override
  String get connect => '连接';

  @override
  String get disconnect => '断开连接';

  @override
  String get sessionDetails => '会话详情';

  @override
  String get beginTransaction => '开始事务';

  @override
  String get commitTransaction => '提交事务';

  @override
  String get rollbackTransaction => '回滚事务';

  @override
  String get enableAutoCommit => '启用自动提交';

  @override
  String get disableAutoCommit => '禁用自动提交';

  @override
  String get outcomeUnknown => '结果未知';

  @override
  String get outcomeUnknownNote => '操作可能已完成。此会话无法继续执行 SQL。切勿自动重试；开始新操作前请核实结果。';

  @override
  String get notConnected => '已断开';

  @override
  String get autoCommit => '自动提交';

  @override
  String get manualTransaction => '手动事务';

  @override
  String get readOnlyPolicy => 'BusyData 只读策略';

  @override
  String get data => '数据';

  @override
  String get structure => '结构';

  @override
  String get results => '结果';

  @override
  String get messages => '消息';

  @override
  String get plan => '计划';

  @override
  String get changes => '更改';

  @override
  String get history => '历史记录';

  @override
  String get jobs => '任务';

  @override
  String get retainedResults => '保留的结果';

  @override
  String get recoverEdits => '恢复已暂存更改';

  @override
  String get applyAndCommit => '应用并提交';

  @override
  String get inspectStructure => '检查结构';

  @override
  String get openData => '打开数据';

  @override
  String get openDefinition => '打开定义';

  @override
  String get copyQualifiedName => '复制限定名称';

  @override
  String get refresh => '刷新';

  @override
  String get columns => '列';

  @override
  String get indexes => '索引';

  @override
  String get constraints => '键和约束';

  @override
  String get foreignKeys => '外键';

  @override
  String get triggers => '触发器';

  @override
  String get definition => '定义';

  @override
  String get dependencies => '依赖关系';

  @override
  String get connectionCapabilities => '连接概览';

  @override
  String get sessionsAndLocks => '会话和锁';

  @override
  String get usersAndRoles => '用户和角色';

  @override
  String get saveSnapshot => '保存模式快照';

  @override
  String get compareSchemas => '比较模式';

  @override
  String get objectDesigner => '对象设计器';

  @override
  String get diagram => 'ER 图';

  @override
  String get backup => '备份';

  @override
  String get restore => '还原';

  @override
  String get importData => '导入数据';

  @override
  String get exportRetained => '导出保留数据';

  @override
  String get exportSql => '运行 SQL 导出';

  @override
  String get stageInsert => '插入行';

  @override
  String get stageUpdate => '编辑行';

  @override
  String get stageDelete => '删除行';

  @override
  String get discardChanges => '放弃待处理更改';

  @override
  String get disposeResult => '释放保留数据';

  @override
  String get currentSchema => '当前模式（将被更改）';

  @override
  String get desiredSchema => '期望模式';

  @override
  String get applyTo => '应用到';

  @override
  String get loading => '正在加载';

  @override
  String get empty => '此范围内没有对象';

  @override
  String get more => '更多';

  @override
  String get filter => '筛选';

  @override
  String get sort => '排序';

  @override
  String get selectTarget => '选择连接';

  @override
  String get requireSql => '需要 SQL 文档';

  @override
  String get requireSession => '需要已连接且状态已知的会话';

  @override
  String get requireResult => '需要保留数据';

  @override
  String get requireObject => '需要目标对象';

  @override
  String get cancelRequested => '已请求取消';

  @override
  String get cancelled => '已取消';

  @override
  String get queued => '排队中';

  @override
  String get running => '运行中';

  @override
  String get completed => '已完成';

  @override
  String get failed => '失败';

  @override
  String get partial => '部分';

  @override
  String get sessionSharing => '共享现有会话（高级）';

  @override
  String get production => '生产环境';

  @override
  String get staging => '预发布环境';

  @override
  String get development => '开发环境';

  @override
  String get executionOptions => '执行选项';

  @override
  String get resultRowLimit => '结果行数限制（1–1000000）';

  @override
  String get boundedRead => '有界读取';

  @override
  String get streamingRead => '流式读取 · 持有读取事务';

  @override
  String get stopOnError => '出错时停止脚本';

  @override
  String get continueOnError => '出错时继续 · 先前语句可能已提交';

  @override
  String get loadMore => '加载更多';

  @override
  String get favorite => '切换收藏';

  @override
  String get connectionGroup => '连接分组';

  @override
  String get copyRange => '复制范围';

  @override
  String get inspectValue => '检查值';

  @override
  String get editConnection => '编辑连接';

  @override
  String get chooseSnapshot => '选择快照';

  @override
  String get captureSchema => '捕获模式';

  @override
  String get sameSchemaRestriction => '快照的引擎、模式名称和版本必须相同。比较和保存不会应用更改。';

  @override
  String get restoredTaskState =>
      '已恢复此文档引用。先前的后端数据、会话和任务不可用。请选择明确操作来开始新工作；恢复不会连接、执行 SQL 或重放更改。';

  @override
  String get preChangeSnapshot => '更改前快照 · 更改已提交。请明确刷新以检查当前行和服务器默认值。';

  @override
  String get sqlProvenance => 'SQL 来源';

  @override
  String get assessEditing => '评估可编辑性';

  @override
  String get viewDetails => '查看详情';

  @override
  String get gridMenu => '数据网格';

  @override
  String get visibleColumns => '可见列';

  @override
  String get hidden => '隐藏';

  @override
  String get ascending => '升序';

  @override
  String get descending => '降序';

  @override
  String get equals => '等于';

  @override
  String get notEqual => '不等于';

  @override
  String get lessThan => '小于';

  @override
  String get greaterThan => '大于';

  @override
  String get isNull => '为 NULL';

  @override
  String get isNotNull => '不为 NULL';

  @override
  String get exactValue => '精确值';

  @override
  String get sortTable => '排序表数据';

  @override
  String get filterTable => '筛选表数据';

  @override
  String get sortRetained => '排序保留快照';

  @override
  String get filterRetained => '筛选保留快照';

  @override
  String get applyView => '应用';

  @override
  String get rowsLabel => '行';

  @override
  String get fetchedRows => '已获取行';

  @override
  String get fixedSnapshot => '已获取行的固定快照';

  @override
  String get limitReached => '达到限制';

  @override
  String get retainedData => '保留数据';

  @override
  String get applyRequiresAutoCommit => '应用并提交需要空闲且启用自动提交的会话。';

  @override
  String get connectionProfile => '连接配置';

  @override
  String get basic => '基本';

  @override
  String get advanced => '高级';

  @override
  String get connectionName => '名称';

  @override
  String get hostname => '主机名（也用于 TLS 验证）';

  @override
  String get port => '端口';

  @override
  String get database => '数据库';

  @override
  String get user => '用户';

  @override
  String get password => '密码';

  @override
  String get writableProfile => '可写配置';

  @override
  String get readonlyProfile => '只读配置';

  @override
  String get tlsVerify => 'TLS：验证证书和主机名';

  @override
  String get tlsInsecure => 'TLS：不安全，不验证';

  @override
  String get tlsDisabled => 'TLS：已禁用';

  @override
  String get testConnection => '测试但不保存';

  @override
  String get saveProfile => '保存';

  @override
  String get saveConnect => '保存并连接';

  @override
  String get sessionPassword => '仅本会话使用密码';

  @override
  String get storedPassword => '将密码存入操作系统安全存储';

  @override
  String get chooseFile => '选择文件';

  @override
  String get testRunning => '正在测试连接…';

  @override
  String get cancelTest => '取消测试';

  @override
  String get idle => '空闲';

  @override
  String get activeTransaction => '事务已打开';

  @override
  String get failedTransaction => '事务失败';

  @override
  String get inspectionContext => '检查会话';

  @override
  String get requireTableOrView => '选择表或视图';

  @override
  String get operationPending => '文档操作正在等待确认';

  @override
  String get requirePlan => '选择保留的 Explain 执行';

  @override
  String get openPlanDocument => '打开计划文档';

  @override
  String get locks => '锁';

  @override
  String get statistics => '统计信息';

  @override
  String get queryStatistics => '查询统计';

  @override
  String get indexDiagnostics => '索引诊断';

  @override
  String get grants => '授予的权限';

  @override
  String get sqlExecution => 'SQL 执行';

  @override
  String get planReady => '保留的计划已就绪；SQL 未重新执行';

  @override
  String get executionPlan => '执行计划';

  @override
  String get openOwner => '打开所属文档';

  @override
  String get terminateActivity => '终止活动';

  @override
  String get close => '关闭';

  @override
  String get previous => '上一项';

  @override
  String get next => '下一项';

  @override
  String get replaceSelection => '替换选区';

  @override
  String get replaceAll => '全部替换';

  @override
  String get restartBackend => '重启后端';

  @override
  String get structuredTree => '结构树';

  @override
  String get rawOutput => '原始输出';

  @override
  String get previousTextPage => '上一页文本';

  @override
  String get nextTextPage => '下一页文本';

  @override
  String get filterChangedObjects => '筛选已更改对象';

  @override
  String get rebindVerifiedEdits => '重新绑定已验证的编辑';

  @override
  String get discardRecoveryRecord => '丢弃恢复记录';

  @override
  String get revertChange => '撤销待处理更改';

  @override
  String get chooseSource => '选择源';

  @override
  String get chooseDestination => '选择目标';

  @override
  String get delimiterField => '分隔符（一个字符）';

  @override
  String get batchRowsField => '每批行数（1–1000）';

  @override
  String get rejectedLimit => '拒绝行数上限（1–1000）';

  @override
  String get previewSource => '预览源';

  @override
  String get reviewTransfer => '审核传输';

  @override
  String get startImport => '开始导入';

  @override
  String get startRestore => '开始恢复';

  @override
  String get startExport => '开始导出';

  @override
  String get requestCancel => '请求取消';

  @override
  String get sourceMapping => '源和目标映射';

  @override
  String get nativeTool => '本机工具';

  @override
  String get defaultOmit => '省略 / 数据库默认值';

  @override
  String get overwriteNever => '不覆盖';

  @override
  String get overwriteExisting => '覆盖现有文件';

  @override
  String get planDetails => '计划详情';

  @override
  String get planMetricsNote => '估计值和实际测量值使用服务器字段名称。缺失的测量值不可用。';

  @override
  String get connected => '已连接';

  @override
  String get disconnected => '已断开';

  @override
  String get tables => '表';

  @override
  String get views => '视图';

  @override
  String get routines => '例程';

  @override
  String get expand => '展开';

  @override
  String get collapse => '折叠';

  @override
  String get databaseWorkbench => '数据库工作台';

  @override
  String get sidebar => '侧边栏';

  @override
  String get unchanged => '未更改';

  @override
  String get reviewDetails => '审查详情';

  @override
  String get generatedSql => '生成的 SQL';

  @override
  String get changeReverted => '已撤销待处理更改。请重新审查。';

  @override
  String get unknownBatch => '结果未知。批次可能已提交。切勿自动重放；请核查会话和恢复记录。';

  @override
  String get expiredChangeReview => '目标已更改或审查已过期。请重新审查。';

  @override
  String get applyCommitExplanation =>
      '应用并提交会启动并提交其自己的事务。来源控制台必须处于空闲状态并启用自动提交。请单独处理手动 SQL 事务。';

  @override
  String get newRow => '新行';

  @override
  String get original => '原始值';

  @override
  String get proposed => '建议值';

  @override
  String changeCounts(int inserts, int updates, int deletes) {
    return '插入 $inserts · 更新 $updates · 删除 $deletes';
  }

  @override
  String sourceRow(String row) {
    return '来源行 $row';
  }

  @override
  String get refreshing => '正在刷新…';

  @override
  String get refreshActivities => '刷新活动';

  @override
  String get explicitRefresh => '手动刷新';

  @override
  String get pollFiveSeconds => '每 5 秒轮询';

  @override
  String get cancelSelectedActivity => '取消选定活动';

  @override
  String get terminateSelectedSession => '终止选定会话';

  @override
  String get filterActivities => '筛选当前活动';

  @override
  String get blockedBy => '阻塞方：';

  @override
  String get delete => '删除';

  @override
  String get remove => '移除';

  @override
  String get up => '向上';

  @override
  String get search => '搜索';

  @override
  String get yes => '是';

  @override
  String get no => '否';

  @override
  String get clear => '清除';

  @override
  String get copy => '复制';

  @override
  String get insert => '插入';

  @override
  String get update => '更新';

  @override
  String get open => '打开';

  @override
  String get migrationEngineMismatch => '应用目标连接必须使用与比较快照相同的引擎。不支持跨引擎迁移。';

  @override
  String get metadataContextChanged => '检查上下文已更改。请显式刷新元数据。';

  @override
  String get newTableName => '新建表名称';

  @override
  String get routineIdentity => '例程的确切标识';

  @override
  String get objectColumnName => '对象 / 列名称';

  @override
  String get builtInType => '内置类型';

  @override
  String get sqlExpression => 'SQL 表达式（留空即移除）';

  @override
  String get newPropertyValue => '新的属性值';

  @override
  String get columnComment => '列注释';

  @override
  String get columnCollation => '列排序规则（留空使用服务器默认值）';

  @override
  String get addDesignedColumn => '向新表添加列';

  @override
  String get checkExpression => 'CHECK 表达式';

  @override
  String get referencedSchema => '引用的模式 / 数据库';

  @override
  String get generating => '正在生成…';

  @override
  String get generateReviewedDdl => '生成待审核 DDL';

  @override
  String get inspectCapturedDefinition => '检查已捕获的定义';

  @override
  String get capturedObject => '已捕获的对象';

  @override
  String get designReviewNote => '生成的更改用于审核。在执行已审核的操作之前，数据库内容保持不变。';

  @override
  String get columnMetadataUnavailable => '此范围的列元数据不可用；请先检查选定模式，再设计列列表。';

  @override
  String get ordinaryColumn => '普通列';

  @override
  String get columnWithDefault => '带默认值的列';

  @override
  String get identityColumn => '标识 / 自增';

  @override
  String get generatedColumn => '生成列';

  @override
  String get columnType => '列类型';

  @override
  String get nullableNotNull => '允许 NULL / NOT NULL';

  @override
  String get defaultExpression => '默认表达式';

  @override
  String get generatedExpression => '生成表达式';

  @override
  String get columnCollationProperty => '列排序规则';

  @override
  String get loggedUnlogged => '记录日志 / 不记录日志';

  @override
  String get tableComment => '表注释';

  @override
  String get storageEngine => '存储引擎';

  @override
  String get tableCollation => '表排序规则';

  @override
  String get rowFormat => '行格式';

  @override
  String get createOrReplace => '创建或替换';

  @override
  String get dropSelectedObject => '删除选定对象';

  @override
  String get addColumn => '添加列';

  @override
  String get editColumnProperties => '编辑列属性';

  @override
  String get tableProperties => '表属性';

  @override
  String get triggerDefinition => '触发器定义';

  @override
  String get createTable => '创建表';

  @override
  String get viewDefinition => '视图定义';

  @override
  String get routineDefinition => '例程定义';

  @override
  String get chooseExistingObject => '选择已有对象';

  @override
  String get nullable => '允许 NULL';

  @override
  String get removeIdentity => '移除标识';

  @override
  String get generatedAlways => '始终生成';

  @override
  String get generatedByDefault => '默认生成 / 自增';

  @override
  String get loggedTable => '记录日志的表';

  @override
  String get unloggedTable => '不记录日志的表';

  @override
  String get orderedPrimaryKeyColumns => '有序主键列';

  @override
  String get orderedColumns => '有序列';

  @override
  String get ordinaryIndex => '普通索引';

  @override
  String get uniqueIndex => '唯一索引';

  @override
  String get primaryKey => '主键';

  @override
  String get uniqueConstraint => '唯一约束';

  @override
  String get foreignKey => '外键';

  @override
  String get checkConstraint => 'CHECK 约束';

  @override
  String get immediateChecking => '立即检查';

  @override
  String get deferrableChecking => '可延迟检查';

  @override
  String get initiallyImmediate => '初始立即';

  @override
  String get initiallyDeferred => '初始延迟';

  @override
  String get referencedTable => '引用的表';

  @override
  String get orderedReferencedColumns => '按对应顺序排列的引用列';

  @override
  String get objectDefinitionEditor => '原生对象定义 SQL 编辑器';

  @override
  String get onDelete => '删除时';

  @override
  String get onUpdate => '更新时';

  @override
  String get stay => '留下';

  @override
  String get saveSqlClose => '保存 SQL 并关闭';

  @override
  String get discardSqlClose => '丢弃 SQL 并关闭';

  @override
  String get closeBusyData => '关闭 BusyData';

  @override
  String get saveDraftsClose => '保存草稿并关闭';

  @override
  String get closeWithoutRecovery => '不恢复直接关闭';

  @override
  String get recoveryFailed => '恢复失败';

  @override
  String get discardFailedSaveClose => '丢弃失败的保存并关闭';

  @override
  String get closeWithoutSavingRecovery => '不保存恢复数据直接关闭';

  @override
  String get disableSqlRecovery => '禁用 SQL 恢复';

  @override
  String get historyPrivacy => '历史隐私';

  @override
  String get enableSqlRetention => '启用 SQL 保留';

  @override
  String get disableSqlRetention => '禁用 SQL 保留';

  @override
  String get clearHistory => '清除历史';

  @override
  String get deleteHistoryEntry => '删除历史记录';

  @override
  String get deleteSelected => '删除所选';

  @override
  String get saveRetention => '保存保留设置';

  @override
  String get retentionDays => '保留天数';

  @override
  String get sqlTextRetained => '已保留 SQL 文本';

  @override
  String get sqlTextDisabled => 'SQL 文本已禁用';

  @override
  String get openHistoryQuery => '在新 SQL 标签页打开';

  @override
  String get caCertificateFile => 'CA 证书文件';

  @override
  String get clientCertificateFile => '客户端证书文件';

  @override
  String get clientKeyFile => '客户端密钥文件';

  @override
  String get directConnection => '直接连接';

  @override
  String get sshTunnel => 'SSH 隧道';

  @override
  String get sshHost => 'SSH 主机';

  @override
  String get sshPort => 'SSH 端口';

  @override
  String get sshUser => 'SSH 用户';

  @override
  String get reviewedKnownHosts => '已审查的 known_hosts 文件';

  @override
  String get reviewSshKey => '审查 SSH 主机密钥';

  @override
  String get changedSshKey => 'SSH 主机密钥已更改';

  @override
  String get verifyFingerprint => '信任之前，请独立验证此指纹。';

  @override
  String get selectedKeyPassword => '所选密钥或密码';

  @override
  String get selectedAgentIdentity => '所选 SSH 代理身份';

  @override
  String get selectedAgentSocket => '所选 Linux 代理套接字 / Windows 命名管道';

  @override
  String get selectedKeyFingerprint => '所选密钥指纹 · SHA256:…';

  @override
  String get selectedPrivateKey => '所选私钥（可选）';

  @override
  String get sshPassword => 'SSH 密码';

  @override
  String get keyPassphrase => '密钥口令';

  @override
  String get connectionTimeout => '连接超时 · 1–120 秒';

  @override
  String get sqlTimeout => 'SQL 执行/获取期限 · 1–3600 秒（0 = 60）';

  @override
  String get schemasEquivalent => '捕获的架构等效。';

  @override
  String get migrationComplete => '迁移涵盖捕获的受支持差异。';

  @override
  String get migrationPartial => '部分迁移；仍有不支持的差异。';

  @override
  String get differencesLimited => '差异显示有限。请审查完整的已保存快照和生成的 SQL。';

  @override
  String get absent => '不存在';

  @override
  String get definitionPreviewLimited => '定义预览有限；请使用原始快照查看完整依据。';

  @override
  String get migrationBatchNote => 'SQL 是按依赖顺序排列的单个批次。选择单个对象用于检查，不会选择要应用的语句。';

  @override
  String get unsupportedLabel => '不支持';

  @override
  String get differenceAdded => '已添加';

  @override
  String get differenceRemoved => '已移除';

  @override
  String get differenceChanged => '已更改';

  @override
  String get selectHistoryEntry => '选择历史记录';

  @override
  String get searchSqlTarget => '搜索 SQL 或目标';

  @override
  String get closeSqlTab => '关闭 SQL 标签页';

  @override
  String get historyMetadataRetained => '状态和目标元数据仍保留在历史中。';

  @override
  String get historyPreviewNote => '仅预览。在新 SQL 标签页打开以获取保留的文本。';

  @override
  String get selected => '已选择';

  @override
  String get authReviewNote =>
      '应用前请审查准确的用户或角色和目标。凭据绝不会放入 SQL 文档或历史。现有连接和保存的密码保持独立。';

  @override
  String get createLogin => '创建登录账户';

  @override
  String get createRole => '创建不可登录角色';

  @override
  String get setPassword => '设置密码';

  @override
  String get preventLogin => '阻止新登录';

  @override
  String get allowLogin => '允许新登录';

  @override
  String get dropPrincipal => '删除用户或角色';

  @override
  String get principalName => '准确的用户或角色名称';

  @override
  String get accountHost => '准确的账户主机（通配符会扩大登录范围）';

  @override
  String get newPassword => '新密码';

  @override
  String get repeatPassword => '重复新密码';

  @override
  String get reviewAccount => '审查账户操作';

  @override
  String get passwordsMismatch => '请两次输入相同的非空密码';

  @override
  String get accountSubmitFailed => '无法提交账户操作。请检查目标、认证策略和数据库权限。';

  @override
  String get privilegeReviewNote => '检查直接授予的权限；生成的 SQL 仍需要执行审查。';

  @override
  String get inspectionLimited => '每节最多 500 行。请缩小搜索范围；空节并不能证明没有有效访问权限。';

  @override
  String get findPrincipal => '查找用户 / 角色名称';

  @override
  String get searchPrincipals => '搜索用户和角色';

  @override
  String get choosePrincipal => '选择用户或角色';

  @override
  String get inspectGrants => '检查所选权限';

  @override
  String get tablePrivileges => '表 / 视图权限';

  @override
  String get schemaPrivileges => '模式权限';

  @override
  String get databasePrivileges => '数据库权限';

  @override
  String get roleMembership => '角色成员关系';

  @override
  String get defaultRole => '默认角色激活';

  @override
  String get chooseGrantRole => '选择要授予 / 撤销的角色';

  @override
  String get tableView => '表 / 视图';

  @override
  String get explicitPrivileges => '明确权限（逗号分隔）';

  @override
  String get setDefaultRole => '设置所选默认角色';

  @override
  String get clearDefaultRole => '清除默认角色';

  @override
  String get grantAccess => '授予访问';

  @override
  String get revokeAccess => '撤销访问';

  @override
  String get withoutDelegation => '不委派';

  @override
  String get allowDelegation => '允许接收者授予他人';

  @override
  String get readonlyChanges => '此配置为只读。更改需要明确可写的会话。';

  @override
  String get createPrincipal => '创建用户 / 角色';

  @override
  String get manageAuthentication => '管理所选认证';

  @override
  String get openPrivilegeSql => '打开权限 SQL 供审查';

  @override
  String get inspectPrincipalFirst => '拟定更改前请检查所选用户或角色';

  @override
  String get accountAuthentication => '账户认证';

  @override
  String get schema => '模式';

  @override
  String get available => '可用';

  @override
  String get availableEmpty => '可用 · 数据为空';

  @override
  String get limitedVisibility => '可见性或范围有限';

  @override
  String get permissionDenied => '权限被拒绝';

  @override
  String get unavailable => '不可用';

  @override
  String get profileDisabled => '由配置禁用';

  @override
  String get unknownState => '未知';

  @override
  String get inspecting => '正在检查…';

  @override
  String get refreshCapabilities => '刷新功能';

  @override
  String get staleRefresh => '已过期 · 连接后刷新';

  @override
  String get staleContext => '已过期 · 连接或上下文更改后刷新';

  @override
  String get partialTreeLimit => '部分 · 已达到树上限；请缩小数据库对象搜索范围';

  @override
  String get schemaComparison => '模式比较';

  @override
  String get searchTable => '搜索表';

  @override
  String get focusObject => '聚焦';

  @override
  String get exportSvg => '导出 SVG';

  @override
  String get exportPng => '导出 PNG';

  @override
  String get diagramNotes => '图表备注（包含在 SVG 中）';

  @override
  String get openNotes => '打开备注';

  @override
  String get saveNotes => '保存备注';

  @override
  String get newSnippet => '新建片段';

  @override
  String get snippetName => '片段名称';

  @override
  String get saveSnippet => '保存片段';

  @override
  String get deleteSnippet => '删除已保存片段';

  @override
  String get insertSnippet => '插入 SQL 文档';

  @override
  String get snippetEditor => 'SQL 片段编辑器';

  @override
  String get snippetsNote => '将已保存的本地 SQL 插入所选文档，可撤销。执行仍需明确操作。';

  @override
  String get level => '级别';

  @override
  String get expanded => '已展开';

  @override
  String get collapsed => '已折叠';

  @override
  String get treeLevel => '级别';

  @override
  String get retainedView => '保留视图';

  @override
  String get tableQuerySnapshot => '表查询快照';

  @override
  String get originalResultNote => '原始保留结果；分页和检查不会执行 SQL';

  @override
  String get tableFilterNote => '应用会提交新的已审查数据库查询。旧快照仍然保留。';

  @override
  String get retainedFilterNote => '固定快照内所有已获取行。不会重新运行 SQL。保留值排序可能与数据库排序规则不同。';

  @override
  String get retainedRowNote => '请选择已获取结果中的行。不会重新运行 SQL。';

  @override
  String get copyLimitNote => '复制最多 10,000 个单元格；更大范围请导出保留数据。';

  @override
  String get inlineValueLimit => '单元格编辑支持 8KiB 值';

  @override
  String get editContextChanged => '源会话或编辑上下文已更改；暂存前请检查或刷新评估';

  @override
  String get editAssessmentUnavailable => '无法评估可编辑性；会话空闲后请刷新评估';

  @override
  String get rowChangeReverted => '待处理行更改已还原；数据库未变';

  @override
  String get sqlCopyRequiresMetadata => 'SQL 复制需要后端及其保留类型元数据。';

  @override
  String get exportFullValue => '导出完整保留值';

  @override
  String valueExportReview(String bytes, String path) {
    return '将 $bytes 字节保存到 $path？将替换现有内容。不会重新运行 SQL。';
  }

  @override
  String get goToRetainedRow => '转到保留行';

  @override
  String get row => '行';

  @override
  String get go => '转到';

  @override
  String get retryRows => '重试保留行';

  @override
  String get previousRows => '上一批行';

  @override
  String get nextRows => '下一批行';

  @override
  String get firstWindow => '首个保留窗口';

  @override
  String get lastWindow => '最后获取的窗口';

  @override
  String get setNull => '设置 NULL';

  @override
  String copyFormat(String format) {
    return '复制 $format';
  }

  @override
  String get textValue => '文本';

  @override
  String get sqlValues => 'SQL 值';

  @override
  String get rowSelection => '行选择';

  @override
  String selectRow(String row) {
    return '选择行 $row';
  }

  @override
  String columnHeader(String column) {
    return '列 $column';
  }

  @override
  String get pendingChange => '待处理更改';

  @override
  String get readonlyCell => '只读单元格';

  @override
  String get editableCell => '可编辑单元格';

  @override
  String get loadValueFirst => '请先加载此保留值';

  @override
  String get editUnavailable => '不可编辑';

  @override
  String get editCell => '编辑单元格';

  @override
  String get unsupportedEditValue => '此保留值仅支持检查';

  @override
  String bytesCount(String bytes) {
    return '$bytes 字节';
  }

  @override
  String get problems => '问题';

  @override
  String get ownedSessions => '所属会话';

  @override
  String get noProblems => '没有记录的问题';

  @override
  String get duplicateConnection => '复制连接';

  @override
  String get deleteConnection => '删除连接';

  @override
  String deleteConnectionReview(String name) {
    return '删除 $name？现有物理会话保持原始设置。';
  }

  @override
  String get unresolvedSessions => '未解决会话';

  @override
  String get disconnectSessionNote =>
      '请先处理活动作业和事务。断开会影响此物理会话的所有客户端；不会提交事务或重放 SQL。未知结果仍然未知。';

  @override
  String get transferSettingsChanged => '设置已更改；请重新审查';

  @override
  String get transferReviewReady => '审查就绪；开始前核对目标、范围、映射和文件';

  @override
  String get sourcePreviewNotice => '源预览；未导入数据库行';

  @override
  String get transferRequiresReview => '请先审查此准确传输';

  @override
  String get transferSubmittedNotice => '已提交；取消不会撤销已确认提交或已发布文件';

  @override
  String get sqlExportExecutionNote => '新的已审查 SQL 执行';

  @override
  String get retainedExportSnapshotNote => '已获取快照；不会执行 SQL';

  @override
  String get restorePartialCommitNote => '还原可能部分提交。取消不会撤销还原。';

  @override
  String get sourcePreviewLimit => '源预览；最多 20 行';

  @override
  String get importBatchSafetyNote => '错误或取消会保留此前的批次提交。发送前再次验证源哈希和所选不可变材料。';

  @override
  String get nullMarkerLiteralNote => '无引号 NULL 标记；带引号时为文字文本';

  @override
  String immutableSourceHash(String hash) {
    return '不可变源 SHA-256：$hash';
  }

  @override
  String sourceColumnLabel(String column) {
    return '源列 $column';
  }

  @override
  String previewRowLabel(String row, String column, String value) {
    return '预览行 $row，$column：$value';
  }

  @override
  String get transferCancellationNotice => '已请求取消；等待确认';

  @override
  String transferProgress(String processed, String committed, String rejected) {
    return '$processed 已处理 · $committed 已提交 · $rejected 已拒绝';
  }

  @override
  String get importAtomicPolicy => '所有行在一个事务中';

  @override
  String get importBatchPolicy => '按批次提交；遇错停止';

  @override
  String get importSkipPolicy => '跳过无效行；按批次提交';

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
    return '确认/连接：$operations\n未保存文档：$documents\n正在保存：$saves\n待处理编辑：$edits\n活动作业：$jobs\n需清理事务：$transactions\n未知操作结果：$unknown\n不确定会话：$sessions';
  }

  @override
  String get closeDraftSaved => 'SQL 草稿将保存到本地。';

  @override
  String get closeDraftLost => '恢复已关闭；未保存的 SQL 和对象设计将丢失。';

  @override
  String get closeDesignRecovery => '对象设计使用私密有界恢复。重新打开后请明确连接并检查元数据。';

  @override
  String get closeCleanupReview =>
      '关闭最后的会话所有者会请求取消、回滚已确认事务并断开。未知结果仍然未知；关闭绝不会提交或重放 SQL。';

  @override
  String get closeSharedSession => '其他客户端保留共享物理会话。';

  @override
  String get closeStagedRecovery => '待处理更改需要确认私密恢复、明确重新连接和新的审查。';

  @override
  String get closeRecoveryLoss => '未能保存文档和布局。关闭可能丢失 SQL 和更改；现有文件及恢复数据仍会保留。';

  @override
  String get closeWaitNotice => '关闭前请等待操作确认和连接清理。';

  @override
  String get saveFailedNotice => 'SQL 保存失败。请保留已修改 SQL 或明确丢弃。';

  @override
  String get closeCleanupFailed => '后端清理失败；BusyData 保持打开。';

  @override
  String get closeBackendUnverified => '后端状态未验证；可能仍有待处理工作。';

  @override
  String historyRetainSqlReview(String days) {
    return 'SQL 可能包含秘密。保存文本 $days 天？';
  }

  @override
  String get historyStopSqlReview => '停止保存 SQL 并从现有历史中删除？';

  @override
  String get historyClearReview => '清除所有历史？活动作业结束时可能记录结果。';

  @override
  String get historyDeleteReview => '删除选中的历史条目？';

  @override
  String get historyRetentionRange => '保留时间必须为 1–3650 天';

  @override
  String get enableSqlHistory => '启用 SQL 历史';

  @override
  String get stopSqlHistory => '停止保留 SQL';

  @override
  String get recoveryDiscardReview => '丢弃恢复记录？请先核对未知结果；丢弃不会撤销已提交更改。';

  @override
  String closeSqlSummary(String unsaved, String edits, String jobs) {
    return '未保存 SQL：$unsaved\n待处理更改：$edits\n活动作业：$jobs';
  }

  @override
  String get recoveryStayOpen => '恢复失败。BusyData 保持打开；未保存的工作仍被保留。';

  @override
  String get commitUncertaintyNote => '网络故障可能使提交结果未知。绝不要自动重试。';

  @override
  String get closeObjectDesignDiscard => '将丢弃未保存的对象设计字段。请先生成并保存 SQL 以保留设计。';

  @override
  String get savePrivateDrafts => '保存私密恢复草稿';

  @override
  String get noPrivateDrafts => '不保存恢复草稿';

  @override
  String shortcutField(String command) {
    return '$command 快捷键';
  }

  @override
  String get shortcutInvalid => '请使用未分配给其他操作的有效快捷键。F6 和 Shift+F6 已保留。';

  @override
  String get disableRecoveryReview =>
      '删除本地 SQL、设计及暂存更改的恢复？未保存工作保持打开，但崩溃可能丢失。请先核对未知结果。';

  @override
  String get preferencesSaved => '设置已保存';

  @override
  String get sharingSessionReview =>
      '此查询与列出的客户端共享所命名的物理会话、事务、临时对象及设置。关闭一个客户端会保留其他客户端。';

  @override
  String get recoveryReconcileFirst => '关闭恢复前请核对正在应用或未知的更改。仅通过明确的单独审查丢弃恢复记录。';

  @override
  String get enterSearchText => '输入搜索文本';

  @override
  String get noSearchMatches => '无匹配项';

  @override
  String searchMatchCount(String position, String total) {
    return '第 $position 项，共 $total 项';
  }

  @override
  String get formatSqlChanged => 'SQL 或目标已更改。原始 SQL 已保留；请重新请求格式预览。';

  @override
  String get formatSqlUnavailable => '语法不完整、不受支持或超出分析限制，无法格式化。原始 SQL 已保留。';

  @override
  String get stageChange => '暂存更改';

  @override
  String pendingChangesCount(String count) {
    return '$count 项待处理更改；经审查应用前数据库保持不变。';
  }

  @override
  String discardChangesCount(String count) {
    return '丢弃 $count 项待处理更改？不会提交数据库操作。';
  }

  @override
  String get recoveryNoExecution => '恢复不会连接、运行源 SQL、恢复事务或重放更改。未知及已提交记录无法再次应用。';

  @override
  String get recoveredDesign => '设计已恢复。请明确连接并检查当前元数据后再生成审查。恢复未获取 SQL 或元数据。';

  @override
  String get retainedUnavailable => '保留数据不可用。已保存的 SQL 和私密恢复仍在本地。';

  @override
  String get activityFingerprintNote => '提交前会重新验证所选活动的指纹。写入结果可能未知。';

  @override
  String replaceFileReview(String path) {
    return '替换已审查的文件 $path？目标更改需要重新审查。';
  }

  @override
  String get diagramPngSaved => '图表 PNG 已保存。长备注最多显示六行。';

  @override
  String get editTargetChanged => '编辑目标已更改。暂存前请重新打开行编辑器。';

  @override
  String affectedRowCount(String count) {
    return '受影响的行数：$count';
  }

  @override
  String get zoomIn => '放大';

  @override
  String get zoomOut => '缩小';

  @override
  String get resetView => '重置视图';

  @override
  String get diagramKeys => '方向键平移；+ 和 - 缩放；Home 重置视图。';

  @override
  String get explorerConnected => '资源管理器已连接';

  @override
  String get explorerDisconnected => '资源管理器未连接';

  @override
  String querySessionCount(String count) {
    return '查询会话 $count';
  }

  @override
  String get metadataColumn => '列';

  @override
  String get metadataPosition => '位置';

  @override
  String get metadataUnique => '唯一';

  @override
  String get metadataJdbcType => 'JDBC 类型';

  @override
  String get metadataAutoIncrement => '自动递增';

  @override
  String get metadataReferencedColumn => '引用列';

  @override
  String get metadataComment => '注释';

  @override
  String get metadataType => '类型';

  @override
  String get metadataEvent => '事件';

  @override
  String get metadataSpecificName => '原生特定标识符';

  @override
  String get metadataOptions => '选项';

  @override
  String get metadataInheritance => '继承';

  @override
  String get metadataDefinitionCaptured => '已捕获的原生定义';

  @override
  String get metadataDefinitionUnavailable => '捕获的元数据中无法提供定义';

  @override
  String get metadataDefinitionUnsupported => '捕获的对象没有受支持的原生定义';

  @override
  String get connections => '连接';

  @override
  String get noConnections => '尚无连接';

  @override
  String get startTitle => '连接数据库';

  @override
  String get startDescription =>
      '连接 PostgreSQL、MySQL 或 MariaDB，浏览对象、管理数据并运行查询。';

  @override
  String get savedStartTitle => '选择连接';

  @override
  String get savedStartDescription => '在数据库资源管理器中连接已保存的连接，浏览对象并运行查询。';

  @override
  String get noConnection => '无连接';

  @override
  String queryTitle(int number) {
    return '查询 $number';
  }

  @override
  String get sessionMenu => '会话';

  @override
  String get noFilterMatches => '没有匹配的连接或已加载对象';

  @override
  String get activityState => '状态';

  @override
  String get activityWait => '等待';

  @override
  String get generalSettings => '常规';

  @override
  String get optionsSettings => '选项';

  @override
  String get host => '主机';

  @override
  String get databaseSystem => '数据库系统';

  @override
  String get passwordStorage => '密码存储';

  @override
  String get environmentLabel => '环境';

  @override
  String get readOnlySettings => '只读策略';

  @override
  String get tlsPolicy => 'TLS 策略';

  @override
  String get sshConnection => 'SSH 连接';

  @override
  String get sshAuthentication => 'SSH 身份验证';

  @override
  String get connectionTestAction => '测试连接';

  @override
  String get details => '详细信息';

  @override
  String get copyDetails => '复制详细信息';

  @override
  String get retry => '重试';

  @override
  String get filterCellValue => '按此值筛选';

  @override
  String get connectsWhenRun => '运行时连接';

  @override
  String get connectionSaving => '保存…';

  @override
  String get connectionConnecting => '连接…';

  @override
  String get connectionCancelling => '取消…';

  @override
  String get connectionSettingsChanged => '设置已更改。请重新测试此版本。';

  @override
  String get connectionTestChanged => '设置已更改。请重新测试此版本。';

  @override
  String get connectionRequired => '必填';

  @override
  String get connectionCorrectFields => '请检查标出的设置。';

  @override
  String get connectionHostname => '主机 · 请检查标出的设置。';

  @override
  String get connectionSshHostname => 'SSH · 主机 · 请检查标出的设置。';

  @override
  String get connectionMaxLength => '名称 ≤ 256';

  @override
  String get connectionTlsHelp => 'TLS · 主机 · SSH/SSL. 请检查标出的设置。';

  @override
  String get connectionTlsReview => 'TLS · 主机 · SSH/SSL. 请检查标出的设置。';

  @override
  String get connectionStorageUnavailable => '密码存储: 不可用. 密码 · 从不.';

  @override
  String get connectionHostReviewed => '主机 · 信任仅适用于此配置和此精确端点。';

  @override
  String get connectionSshReviewing => 'SSH · 审查 SSH 主机密钥…';

  @override
  String get connectionFailureAuthentication => '失败 · 身份验证 · 常规. 请检查标出的设置。';

  @override
  String get connectionFailureTls => '失败 · TLS · SSH/SSL. 请检查标出的设置。';

  @override
  String get connectionFailureSshKey => '失败 · 审查 SSH 主机密钥. 请检查标出的设置。';

  @override
  String get connectionFailureEndpoint => '失败 · 主机 · 端口. 请检查标出的设置。';

  @override
  String get connectionFailureCancelled => '已取消';

  @override
  String get connectionFailureSettings => '失败 · 常规. 请检查标出的设置。';

  @override
  String get connectionFailureAccess => '失败 · 表 / 视图权限. 请检查标出的设置。';

  @override
  String get connectionFailureUnavailable => '失败 · 主机 · TLS · SSH. 请检查标出的设置。';

  @override
  String get connectionFailureTimeout => '失败 · 连接超时 · 1–120 秒. 请检查标出的设置。';

  @override
  String get connectionFailureUnknown => '失败 · 常规 · TLS · SSH. 请检查标出的设置。';

  @override
  String connectionNumber(int min, int max) {
    return '请输入 $min 到 $max 之间的整数';
  }

  @override
  String connectionSavedFailure(String name) {
    return '连接已保存：$name。连接尝试失败。 ';
  }

  @override
  String get backendBusy => '后端忙碌。请等待当前请求完成，然后重试。';

  @override
  String rpcRequestUnconfirmed(String code) {
    return '请求未获确认（RPC $code）。';
  }

  @override
  String get operationUnconfirmed => '无法完成操作。';

  @override
  String get connectionFailureTlsMaterial =>
      'TLS 材料不可用或无效。请在 SSH/SSL 中检查信任来源和客户端密钥。';

  @override
  String get managerTitle => '数据源和驱动程序';

  @override
  String get sourceListTitle => '数据源';

  @override
  String get driverLabel => '驱动程序';

  @override
  String get connectionTypeLabel => '连接类型';

  @override
  String get defaultTcp => '默认 (TCP)';

  @override
  String get authenticationLabel => '身份验证';

  @override
  String get userPasswordAuth => '用户和密码';

  @override
  String get neverStorage => '从不';

  @override
  String get initialDatabaseLabel => '初始数据库';

  @override
  String get useSshTunnel => '使用 SSH 隧道';

  @override
  String get sshConfigurationLabel => 'SSH 配置';

  @override
  String get createSshConfig => '<创建配置>';

  @override
  String get copySshSettings => '复制 SSH 设置';

  @override
  String get localPortLabel => '本地端口';

  @override
  String get dynamicPortLabel => '<动态>';

  @override
  String get useSsl => '使用 SSL';

  @override
  String get useTruststore => '使用信任库';

  @override
  String get clientKeyPasswordLabel => '客户端密钥密码';

  @override
  String get modeLabel => '模式';

  @override
  String get requireTls => '要求';

  @override
  String get verifyCa => '验证 CA';

  @override
  String get fullVerification => '完全验证';

  @override
  String get connectionSection => '连接';

  @override
  String get configurationApplied => '配置已应用';

  @override
  String get noOtherSshConfig => '其他数据源没有 SSH 配置。';

  @override
  String get generatedUrlHelp => '生成的只读 JDBC 地址。';

  @override
  String get tlsDriverDefaultHelp => 'SSL 尚未配置；使用随附驱动程序的默认设置。';

  @override
  String get tlsClientKeyHelp => 'PEM 密钥：PKCS#8 或 OpenSSL；支持加密或未加密密钥。';

  @override
  String get legacyMariaTrustHelp => '保留现有驱动程序验证。选择信任来源以明确配置根证书。';

  @override
  String get metadataStartValue => '起始值';

  @override
  String get metadataMinimumValue => '最小值';

  @override
  String get metadataMaximumValue => '最大值';

  @override
  String get metadataIncrement => '增量';

  @override
  String get metadataCycle => '循环';

  @override
  String get metadataCacheSize => '缓存大小';

  @override
  String get metadataLastValue => '最后值';

  @override
  String get sequences => '序列';

  @override
  String get namespaceSelection => '选择命名空间';

  @override
  String get namespaceSelectionNotice => '选择控制元数据内省。查询控制台保留其执行上下文。';

  @override
  String get allNamespaces => '所有命名空间';

  @override
  String get defaultNamespace => '默认';

  @override
  String get namespacePattern => '名称模式（正则表达式）';

  @override
  String namespaceCount(int selected, int known) {
    return '$known 中的 $selected';
  }

  @override
  String get previousPage => '上一页';

  @override
  String get patternRejected => '模式无效或超出工作限制。保留先前的选择。';

  @override
  String get namespaceNotSelected => '未选择此命名空间进行内省';

  @override
  String get newMenu => '新建';

  @override
  String get queryConsoles => '查询控制台';

  @override
  String get viewOptions => '视图选项';

  @override
  String get quickDocumentation => '快速文档';

  @override
  String get showEmptyGroups => '显示空分组';

  @override
  String get speedSearch => '快速搜索';

  @override
  String get speedSearchScope => '仅搜索已展开且已加载的节点。';

  @override
  String get newSourceFolder => '新建数据源文件夹';

  @override
  String get renameSourceFolder => '重命名文件夹';

  @override
  String get moveToFolder => '移动到文件夹';

  @override
  String get moveUp => '上移';

  @override
  String get moveDown => '下移';

  @override
  String get folderMustBeEmpty => '删除此文件夹前，请移出其中的数据源和文件夹。';

  @override
  String get newVirtualView => '新建虚拟视图';

  @override
  String get editVirtualDefinition => '编辑本地定义';

  @override
  String get unboundVirtualView => '未绑定的虚拟视图';

  @override
  String get localVirtualViewNotice =>
      '本地 SQL 定义。保存不会执行 SQL 或创建服务器视图。运行使用常规 SQL 审核和独立控制台。';

  @override
  String get rebindVirtualView => '将本地定义绑定到此处';

  @override
  String get sourceFolderName => '文件夹名称';

  @override
  String get sourceFolderPathNotice => '使用 / 创建嵌套文件夹。';

  @override
  String get topLevel => '顶层';

  @override
  String get virtualViewName => '虚拟视图名称';

  @override
  String get virtualViewSql => '虚拟视图 SQL 定义';

  @override
  String get virtualViews => '虚拟视图';

  @override
  String get revealInExplorer => '在数据库资源管理器中显示';

  @override
  String get objectNotFound => '在此命名空间中未找到对象。请刷新元数据或检查权限。';

  @override
  String get objectHiddenByFilter => '当前视图筛选器隐藏了此对象。';

  @override
  String get revealFilterNotice => '对象查找缩小了此页范围，因此省略整个分组的总数。';

  @override
  String get clearObjectFilter => '清除对象查找';

  @override
  String get compareStructure => '比较结构';

  @override
  String get selectTwoCompatibleObjects => '按住 Ctrl 单击选择两个兼容的表。';

  @override
  String get scopedComparisonRestriction =>
      '限定范围的比较要求普通表具有相同的原生名称、模式和引擎。不支持其他类型或重命名匹配。';

  @override
  String get groupNamespaces => '分组显示数据库和模式';

  @override
  String get groupSchemaObjects => '分组显示模式对象';

  @override
  String get groupTableElements => '分组显示表元素';

  @override
  String get sortAlphabetically => '按字母顺序排序';

  @override
  String get showVirtualObjects => '显示虚拟对象';

  @override
  String get showObjectComments => '显示对象注释';

  @override
  String get objectTypeFilter => '对象类型筛选器';

  @override
  String get partitionedTable => '分区表';

  @override
  String get foreignTable => '外部表';

  @override
  String get materializedView => '物化视图';

  @override
  String get functionObject => '函数';

  @override
  String get procedureObject => '存储过程';

  @override
  String get sqlSymbolUnavailable =>
      '无法安全解析光标处的持久对象。请连接此控制台，并使用字面量和注释之外的表或视图引用。';

  @override
  String get sqlSymbolAmbiguous => 'SQL 对象引用不明确。请限定其命名空间或选择准确的数据库对象。';

  @override
  String get deactivateSource => '停用数据源';

  @override
  String get functions => '函数';

  @override
  String get procedures => '存储过程';

  @override
  String get separateProceduresFunctions => '分开显示存储过程与函数';

  @override
  String get renameVirtualView => '重命名虚拟视图';

  @override
  String get metadataPersistentScope => '仅显示持久对象；临时对象和会话本地对象仍在控制台导航中。';

  @override
  String get metadataSessionScope => '仅显示持久对象；执行后请刷新控制台本地对象。';

  @override
  String get metadataLimitScope => '已达到元数据限制。请缩小对象范围。';

  @override
  String get completeColumnMetadataRequired => '导入或暂存更改前需要完整的列元数据。';

  @override
  String resizeColumn(String name) {
    return '调整列 $name 的宽度';
  }

  @override
  String get keyboardShortcutsHeading => '键盘快捷键';

  @override
  String sqlEditorLabel(String title) {
    return 'SQL 编辑器 $title';
  }

  @override
  String get editorResultsDivider => '编辑器与结果分隔线';

  @override
  String editorExtent(String percent) {
    return '编辑器占 $percent 百分比';
  }

  @override
  String get largerEditor => '扩大编辑器';

  @override
  String get smallerEditor => '缩小编辑器';

  @override
  String get explorerWidthDivider => '资源管理器宽度分隔线';

  @override
  String get widerExplorer => '加宽资源管理器';

  @override
  String get narrowerExplorer => '缩窄资源管理器';

  @override
  String explorerExtent(String width) {
    return '宽 $width 像素';
  }

  @override
  String planTextPage(String start, String end, String total) {
    return '第 $start–$end 个，共 $total 个 UTF-16 单元';
  }

  @override
  String get dropDesignedColumn => '删除列';

  @override
  String get liveCatalogLabel => '当前目录';

  @override
  String get liveSchemaLabel => '当前模式';

  @override
  String get searchPathLabel => '搜索路径';

  @override
  String get physicalSessionLabel => '物理会话';

  @override
  String queryTimeoutDetail(String seconds, String rows) {
    return '超时：$seconds 秒 · 行数限制：$rows';
  }

  @override
  String get saveFailedCloseTitle => 'SQL 保存失败 · 关闭 BusyData';

  @override
  String get createSection => '创建';

  @override
  String get newConnectionDescription => '配置数据库连接';

  @override
  String get newQueryDescription => '在新查询中编写 SQL';

  @override
  String get openSqlDescription => '打开现有 SQL 文档';

  @override
  String get searchNoResults => '没有匹配的操作';

  @override
  String get actionsCategory => '操作';

  @override
  String get privateRecoveryCategory => '私密恢复';

  @override
  String get shortcutRecordHelp => '请按快捷键。Escape 取消。F6 和 Shift+F6 保留用于面板导航。';

  @override
  String get rowLimitInvalid => '请输入 1 到 1,000,000 之间的行数限制。';

  @override
  String get errorPolicy => '执行出错时';

  @override
  String get tlsEncrypted => '已加密';

  @override
  String get tlsUnencrypted => '未加密';

  @override
  String get tlsUnobserved => '未观察到';

  @override
  String get encryptionVerificationNote => '加密并不证明已验证证书或主机名。';

  @override
  String get uniqueDesignedColumnName => '请使用唯一的列名；新建表最多支持 128 列';

  @override
  String activityBlockerUnavailable(String id) {
    return '阻塞会话 $id 已不可见；请刷新并检查数据库权限';
  }

  @override
  String get sshChangedKeyReview => '替换此配置的绑定前，请独立验证更改后的密钥。';

  @override
  String get sshProfileTrustBinding => '信任仅适用于此配置和此精确端点。';

  @override
  String get databaseTlsEvidence => 'TLS · 数据库系统';

  @override
  String get sshAlgorithmLabel => 'SSH · 类型';

  @override
  String get sshFingerprintLabel => 'SHA-256';

  @override
  String get sshPreviousFingerprintLabel => '上一项 · SHA-256';

  @override
  String get sshReviewedLabel => '审查 SSH 主机密钥';

  @override
  String get shortcutRecordAction => '录制快捷键';

  @override
  String get fileFormatLabel => '文件格式';

  @override
  String get encodingLabel => '编码';

  @override
  String get importPolicyLabel => '导入策略';

  @override
  String get mainMenu => '主菜单';

  @override
  String get activityReplyTooLarge => '活动响应超出检查器限制。';

  @override
  String get activityListLimited => '列表受限；请使用明确的 SQL 检查更小范围的目标。';

  @override
  String get activitySelectionChanged => '所选活动已结束或发生变化。请先选择其当前标识，再审查操作。';

  @override
  String connectionSavedDraftChanged(String name) {
    return '保存时连接字段已更改；配置已保存：$name。连接前请检查当前值。';
  }

  @override
  String get sshReviewTargetChanged => 'SSH 审核目标已更改；请重新审核';

  @override
  String get appearance => 'Appearance';

  @override
  String get theme => 'Theme';

  @override
  String get systemTheme => 'System';

  @override
  String get lightTheme => 'Light';

  @override
  String get darkTheme => 'Dark';

  @override
  String get appLanguage => 'Language';

  @override
  String get systemLanguage => 'System';

  @override
  String get cut => 'Cut';

  @override
  String get paste => 'Paste';

  @override
  String get selectAll => 'Select all';

  @override
  String get noSelection => '没有可用文本';

  @override
  String get clipboardEmpty => '剪贴板中没有文本';

  @override
  String get settingsDraftNotice => '执行和私密恢复的更改尚未保存。';

  @override
  String get documentsMenu => '文档';

  @override
  String get currentSql => '当前 SQL';

  @override
  String get searchActionsHint => 'Search actions…';

  @override
  String get searchCurrentSqlHint => 'Search current SQL…';

  @override
  String get searchObjectsHint => 'Search database objects…';

  @override
  String get searchHistoryHint => 'Search query history…';

  @override
  String get metadataAttributes => '属性';

  @override
  String get metadataSelectionUnavailable => '选择一个项目以检查其捕获的属性。先前的选择不可用。';

  @override
  String get secureStorage => '系统安全存储';

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
  String get metadataCacheWriteUnavailable => '无法保存缓存。当前元数据仍然可用。';

  @override
  String get metadataCacheRebuiltVersion => '已为当前版本重建';

  @override
  String get metadataCacheRebuiltCorrupt => '发生缓存错误后已重建';

  @override
  String get editSessionBusy => '此会话正忙。请等待当前工作完成，然后请求重新评估可编辑性。';

  @override
  String get editIdentityRequired => '编辑前，请选择完整的主键或不允许 NULL 的唯一标识。';

  @override
  String get editColumnsReadOnly => '所有投影列均为生成列或只读列。';

  @override
  String get editResultNotReady => '请等待此保留结果完成，然后请求重新评估可编辑性。';

  @override
  String get editProjectionUnsupported => '编辑要求直接从一个基表执行 SELECT，且每个基表列仅投影一次。';

  @override
  String get sqlInspectionDuplicateUsingColumn => 'JOIN USING 列重复';

  @override
  String get sqlInspectionUnresolvedUsingColumn => '某个操作数中缺少 JOIN USING 列';

  @override
  String get sqlInspectionAmbiguousUsingColumn => 'JOIN 公共列不明确';

  @override
  String get sqlInspectionOutputColumnCount => '声明的输出列数不匹配';

  @override
  String get sqlInspectionAmbiguousOverload => '例程重载不明确';

  @override
  String get sqlInspectionBooleanType => '布尔表达式类型无效';

  @override
  String get sqlInspectionOperatorTypes => '运算符的操作数类型不兼容';

  @override
  String get sqlInspectionArrayTypes => '数组元素类型不兼容';

  @override
  String get sqlInspectionCaseConditionType => 'CASE 条件类型不兼容';

  @override
  String get sqlInspectionCaseResultTypes => 'CASE 结果类型不兼容';

  @override
  String get sqlInspectionCoalesceTypes => 'COALESCE 参数类型不兼容';

  @override
  String get sqlInspectionSetColumnCount => '集合运算的列数不匹配';

  @override
  String get sqlInspectionSetTypes => '集合运算的结果类型不兼容';

  @override
  String get sqlInspectionRecursiveCteType => '递归 CTE 类型不匹配';
}

/// The translations for Chinese, using the Han script (`zh_Hant`).
class AppLocalizationsZhHant extends AppLocalizationsZh {
  AppLocalizationsZhHant() : super('zh_Hant');

  @override
  String get cancel => '取消';

  @override
  String get windowMinimize => '最小化';

  @override
  String get windowMaximize => '最大化';

  @override
  String get windowRestore => '還原';

  @override
  String get databaseExplorer => '資料庫總管';

  @override
  String get databases => '資料庫';

  @override
  String get newConnection => '新增連線';

  @override
  String get filterTree => '篩選連線和物件';

  @override
  String get treeFilterScope => '篩選已載入的樹狀物件';

  @override
  String get searchObjects => '搜尋資料庫物件';

  @override
  String get fileMenu => '檔案';

  @override
  String get editMenu => '編輯';

  @override
  String get viewMenu => '檢視';

  @override
  String get connectionMenu => '連線';

  @override
  String get objectMenu => '物件';

  @override
  String get runMenu => '執行選項';

  @override
  String get commands => '命令';

  @override
  String get findCommand => '尋找命令';

  @override
  String get newSql => '新增查詢';

  @override
  String get openSql => '開啟 SQL';

  @override
  String get openSqlFile => '開啟 SQL 檔案';

  @override
  String get saveSql => '儲存 SQL';

  @override
  String get closeTab => '關閉分頁';

  @override
  String get openWorkspace => '開啟工作區';

  @override
  String get saveWorkspace => '儲存工作區';

  @override
  String get settings => '設定';

  @override
  String get findText => '尋找';

  @override
  String get replaceText => '取代';

  @override
  String get formatSql => '格式化 SQL';

  @override
  String get lineComments => '切換行註解';

  @override
  String get snippets => 'SQL 程式碼片段';

  @override
  String get run => '執行';

  @override
  String get runStatement => '執行目前陳述式';

  @override
  String get runSelection => '執行選取內容';

  @override
  String get runScript => '執行指令碼';

  @override
  String get explain => '執行計畫';

  @override
  String get explainAnalyze => '執行並分析計畫';

  @override
  String get connect => '連線';

  @override
  String get disconnect => '中斷連線';

  @override
  String get sessionDetails => '工作階段詳細資料';

  @override
  String get beginTransaction => '開始交易';

  @override
  String get commitTransaction => '認可交易';

  @override
  String get rollbackTransaction => '回復交易';

  @override
  String get enableAutoCommit => '啟用自動認可';

  @override
  String get disableAutoCommit => '停用自動認可';

  @override
  String get outcomeUnknown => '結果未知';

  @override
  String get outcomeUnknownNote =>
      '操作可能已完成。此工作階段無法繼續執行 SQL。切勿自動重試；開始新操作前請核實結果。';

  @override
  String get notConnected => '已中斷連線';

  @override
  String get autoCommit => '自動認可';

  @override
  String get manualTransaction => '手動交易';

  @override
  String get readOnlyPolicy => 'BusyData 唯讀原則';

  @override
  String get data => '資料';

  @override
  String get structure => '結構';

  @override
  String get results => '結果';

  @override
  String get messages => '訊息';

  @override
  String get plan => '計畫';

  @override
  String get changes => '變更';

  @override
  String get history => '歷程記錄';

  @override
  String get jobs => '工作';

  @override
  String get retainedResults => '保留的結果';

  @override
  String get recoverEdits => '復原已暫存變更';

  @override
  String get applyAndCommit => '套用並認可';

  @override
  String get inspectStructure => '檢查結構';

  @override
  String get openData => '開啟資料';

  @override
  String get openDefinition => '開啟定義';

  @override
  String get copyQualifiedName => '複製完整名稱';

  @override
  String get refresh => '重新整理';

  @override
  String get columns => '欄';

  @override
  String get indexes => '索引';

  @override
  String get constraints => '鍵與條件約束';

  @override
  String get foreignKeys => '外部索引鍵';

  @override
  String get triggers => '觸發程序';

  @override
  String get definition => '定義';

  @override
  String get dependencies => '相依性';

  @override
  String get connectionCapabilities => '連線概觀';

  @override
  String get sessionsAndLocks => '工作階段與鎖定';

  @override
  String get usersAndRoles => '使用者與角色';

  @override
  String get saveSnapshot => '儲存結構描述快照';

  @override
  String get compareSchemas => '比較結構描述';

  @override
  String get objectDesigner => '物件設計工具';

  @override
  String get diagram => 'ER 圖';

  @override
  String get backup => '備份';

  @override
  String get restore => '還原';

  @override
  String get importData => '匯入資料';

  @override
  String get exportRetained => '匯出保留資料';

  @override
  String get exportSql => '執行 SQL 匯出';

  @override
  String get stageInsert => '插入列';

  @override
  String get stageUpdate => '編輯列';

  @override
  String get stageDelete => '刪除列';

  @override
  String get discardChanges => '捨棄待處理變更';

  @override
  String get disposeResult => '釋放保留資料';

  @override
  String get currentSchema => '目前結構描述（將變更）';

  @override
  String get desiredSchema => '預期結構描述';

  @override
  String get applyTo => '套用至';

  @override
  String get loading => '載入中';

  @override
  String get empty => '此範圍沒有物件';

  @override
  String get more => '更多';

  @override
  String get filter => '篩選';

  @override
  String get sort => '排序';

  @override
  String get selectTarget => '選擇連線';

  @override
  String get requireSql => '需要 SQL 文件';

  @override
  String get requireSession => '需要已連線且狀態已知的工作階段';

  @override
  String get requireResult => '需要保留資料';

  @override
  String get requireObject => '需要目標物件';

  @override
  String get cancelRequested => '已要求取消';

  @override
  String get cancelled => '已取消';

  @override
  String get queued => '佇列中';

  @override
  String get running => '執行中';

  @override
  String get completed => '已完成';

  @override
  String get failed => '失敗';

  @override
  String get partial => '部分';

  @override
  String get sessionSharing => '共用現有工作階段（進階）';

  @override
  String get production => '正式環境';

  @override
  String get staging => '預備環境';

  @override
  String get development => '開發環境';

  @override
  String get executionOptions => '執行選項';

  @override
  String get resultRowLimit => '結果列數限制（1–1000000）';

  @override
  String get boundedRead => '有限讀取';

  @override
  String get streamingRead => '串流讀取 · 持有讀取交易';

  @override
  String get stopOnError => '出錯時停止指令碼';

  @override
  String get continueOnError => '出錯時繼續 · 先前陳述式可能已認可';

  @override
  String get loadMore => '載入更多';

  @override
  String get favorite => '切換收藏';

  @override
  String get connectionGroup => '連線群組';

  @override
  String get copyRange => '複製範圍';

  @override
  String get inspectValue => '檢查值';

  @override
  String get editConnection => '編輯連線';

  @override
  String get chooseSnapshot => '選擇快照';

  @override
  String get captureSchema => '擷取結構描述';

  @override
  String get sameSchemaRestriction => '快照的引擎、結構描述名稱和版本必須相同。比較與儲存不會套用變更。';

  @override
  String get restoredTaskState =>
      '已復原此文件參考。先前的後端資料、工作階段和工作無法使用。請選擇明確操作開始新工作；復原不會連線、執行 SQL 或重播變更。';

  @override
  String get preChangeSnapshot => '變更前快照 · 變更已認可。請明確重新整理以檢查目前資料列及伺服器預設值。';

  @override
  String get sqlProvenance => 'SQL 來源';

  @override
  String get assessEditing => '評估可編輯性';

  @override
  String get viewDetails => '檢視詳情';

  @override
  String get gridMenu => '資料網格';

  @override
  String get visibleColumns => '可見欄';

  @override
  String get hidden => '隱藏';

  @override
  String get ascending => '遞增';

  @override
  String get descending => '遞減';

  @override
  String get equals => '等於';

  @override
  String get notEqual => '不等於';

  @override
  String get lessThan => '小於';

  @override
  String get greaterThan => '大於';

  @override
  String get isNull => '為 NULL';

  @override
  String get isNotNull => '不為 NULL';

  @override
  String get exactValue => '精確值';

  @override
  String get sortTable => '排序資料表資料';

  @override
  String get filterTable => '篩選資料表資料';

  @override
  String get sortRetained => '排序保留快照';

  @override
  String get filterRetained => '篩選保留快照';

  @override
  String get applyView => '套用';

  @override
  String get rowsLabel => '列';

  @override
  String get fetchedRows => '已取得列';

  @override
  String get fixedSnapshot => '已取得列的固定快照';

  @override
  String get limitReached => '達到限制';

  @override
  String get retainedData => '保留資料';

  @override
  String get applyRequiresAutoCommit => '套用並提交需要閒置且啟用自動提交的工作階段。';

  @override
  String get connectionProfile => '連線設定';

  @override
  String get basic => '基本';

  @override
  String get advanced => '進階';

  @override
  String get connectionName => '名稱';

  @override
  String get hostname => '主機名稱（也用於 TLS 驗證）';

  @override
  String get port => '連接埠';

  @override
  String get database => '資料庫';

  @override
  String get user => '使用者';

  @override
  String get password => '密碼';

  @override
  String get writableProfile => '可寫入設定';

  @override
  String get readonlyProfile => '唯讀設定';

  @override
  String get tlsVerify => 'TLS：驗證憑證和主機名稱';

  @override
  String get tlsInsecure => 'TLS：不安全，不驗證';

  @override
  String get tlsDisabled => 'TLS：已停用';

  @override
  String get testConnection => '測試但不儲存';

  @override
  String get saveProfile => '儲存';

  @override
  String get saveConnect => '儲存並連線';

  @override
  String get sessionPassword => '僅此工作階段使用密碼';

  @override
  String get storedPassword => '將密碼儲存於作業系統安全儲存區';

  @override
  String get chooseFile => '選擇檔案';

  @override
  String get testRunning => '正在測試連線…';

  @override
  String get cancelTest => '取消測試';

  @override
  String get idle => '閒置';

  @override
  String get activeTransaction => '交易已開啟';

  @override
  String get failedTransaction => '交易失敗';

  @override
  String get inspectionContext => '檢查工作階段';

  @override
  String get requireTableOrView => '選擇資料表或檢視';

  @override
  String get operationPending => '文件操作正在等待確認';

  @override
  String get requirePlan => '選擇保留的 Explain 執行';

  @override
  String get openPlanDocument => '開啟計畫文件';

  @override
  String get locks => '鎖定';

  @override
  String get statistics => '統計資訊';

  @override
  String get queryStatistics => '查詢統計';

  @override
  String get indexDiagnostics => '索引診斷';

  @override
  String get grants => '授予的權限';

  @override
  String get sqlExecution => 'SQL 執行';

  @override
  String get planReady => '保留的計畫已就緒；SQL 未重新執行';

  @override
  String get executionPlan => '執行計畫';

  @override
  String get openOwner => '開啟所屬文件';

  @override
  String get terminateActivity => '終止活動';

  @override
  String get close => '關閉';

  @override
  String get previous => '上一項';

  @override
  String get next => '下一項';

  @override
  String get replaceSelection => '取代選取範圍';

  @override
  String get replaceAll => '全部取代';

  @override
  String get restartBackend => '重新啟動後端';

  @override
  String get structuredTree => '結構樹';

  @override
  String get rawOutput => '原始輸出';

  @override
  String get previousTextPage => '上一頁文字';

  @override
  String get nextTextPage => '下一頁文字';

  @override
  String get filterChangedObjects => '篩選已變更物件';

  @override
  String get rebindVerifiedEdits => '重新綁定已驗證的編輯';

  @override
  String get discardRecoveryRecord => '捨棄復原紀錄';

  @override
  String get revertChange => '撤銷待處理變更';

  @override
  String get chooseSource => '選擇來源';

  @override
  String get chooseDestination => '選擇目標';

  @override
  String get delimiterField => '分隔符號（一個字元）';

  @override
  String get batchRowsField => '每批列數（1–1000）';

  @override
  String get rejectedLimit => '拒絕列數上限（1–1000）';

  @override
  String get previewSource => '預覽來源';

  @override
  String get reviewTransfer => '審核傳輸';

  @override
  String get startImport => '開始匯入';

  @override
  String get startRestore => '開始還原';

  @override
  String get startExport => '開始匯出';

  @override
  String get requestCancel => '請求取消';

  @override
  String get sourceMapping => '來源和目標對應';

  @override
  String get nativeTool => '原生工具';

  @override
  String get defaultOmit => '省略 / 資料庫預設值';

  @override
  String get overwriteNever => '不覆寫';

  @override
  String get overwriteExisting => '覆寫現有檔案';

  @override
  String get planDetails => '計畫詳細資料';

  @override
  String get planMetricsNote => '估計值和實際測量值使用伺服器欄位名稱。缺少的測量值無法使用。';

  @override
  String get connected => '已連線';

  @override
  String get disconnected => '已中斷連線';

  @override
  String get tables => '資料表';

  @override
  String get views => '檢視';

  @override
  String get routines => '常式';

  @override
  String get expand => '展開';

  @override
  String get collapse => '摺疊';

  @override
  String get databaseWorkbench => '資料庫工作台';

  @override
  String get sidebar => '側邊欄';

  @override
  String get unchanged => '未變更';

  @override
  String get reviewDetails => '審查詳細資料';

  @override
  String get generatedSql => '產生的 SQL';

  @override
  String get changeReverted => '已撤銷待處理變更。請重新審查。';

  @override
  String get unknownBatch => '結果未知。批次可能已提交。切勿自動重播；請核查工作階段和復原記錄。';

  @override
  String get expiredChangeReview => '目標已變更或審查已過期。請重新審查。';

  @override
  String get applyCommitExplanation =>
      '套用並提交會啟動並提交自己的交易。來源主控台必須處於閒置狀態並啟用自動提交。請另行處理手動 SQL 交易。';

  @override
  String get newRow => '新列';

  @override
  String get original => '原始值';

  @override
  String get proposed => '建議值';

  @override
  String changeCounts(int inserts, int updates, int deletes) {
    return '插入 $inserts · 更新 $updates · 刪除 $deletes';
  }

  @override
  String sourceRow(String row) {
    return '來源列 $row';
  }

  @override
  String get refreshing => '正在重新整理…';

  @override
  String get refreshActivities => '重新整理活動';

  @override
  String get explicitRefresh => '手動重新整理';

  @override
  String get pollFiveSeconds => '每 5 秒輪詢';

  @override
  String get cancelSelectedActivity => '取消選取活動';

  @override
  String get terminateSelectedSession => '終止選取工作階段';

  @override
  String get filterActivities => '篩選目前活動';

  @override
  String get blockedBy => '封鎖方：';

  @override
  String get delete => '刪除';

  @override
  String get remove => '移除';

  @override
  String get up => '上';

  @override
  String get search => '搜尋';

  @override
  String get yes => '是';

  @override
  String get no => '否';

  @override
  String get clear => '清除';

  @override
  String get copy => '複製';

  @override
  String get insert => '插入';

  @override
  String get update => '更新';

  @override
  String get open => '開啟';

  @override
  String get migrationEngineMismatch => '套用目標連線必須使用與比較快照相同的引擎。不支援跨引擎遷移。';

  @override
  String get metadataContextChanged => '檢查內容已變更。請明確重新整理中繼資料。';

  @override
  String get newTableName => '新表名稱';

  @override
  String get routineIdentity => '常式的確切識別資訊';

  @override
  String get objectColumnName => '物件 / 欄名稱';

  @override
  String get builtInType => '內建類型';

  @override
  String get sqlExpression => 'SQL 運算式（留空即移除）';

  @override
  String get newPropertyValue => '新的屬性值';

  @override
  String get columnComment => '欄註解';

  @override
  String get columnCollation => '欄定序（留空使用伺服器預設值）';

  @override
  String get addDesignedColumn => '向新表新增欄';

  @override
  String get checkExpression => 'CHECK 運算式';

  @override
  String get referencedSchema => '參照的結構描述 / 資料庫';

  @override
  String get generating => '正在產生…';

  @override
  String get generateReviewedDdl => '產生待檢閱 DDL';

  @override
  String get inspectCapturedDefinition => '檢查已擷取的定義';

  @override
  String get capturedObject => '已擷取的物件';

  @override
  String get designReviewNote => '產生的變更供檢閱使用。在執行已檢閱的操作之前，資料庫內容維持不變。';

  @override
  String get columnMetadataUnavailable => '此範圍的欄中繼資料無法使用；請先檢查選定的結構描述，再設計欄清單。';

  @override
  String get ordinaryColumn => '一般欄';

  @override
  String get columnWithDefault => '含預設值的欄';

  @override
  String get identityColumn => '識別 / 自動遞增';

  @override
  String get generatedColumn => '產生的欄';

  @override
  String get columnType => '欄類型';

  @override
  String get nullableNotNull => '允許 NULL / NOT NULL';

  @override
  String get defaultExpression => '預設運算式';

  @override
  String get generatedExpression => '產生的運算式';

  @override
  String get columnCollationProperty => '欄定序';

  @override
  String get loggedUnlogged => '記錄日誌 / 不記錄日誌';

  @override
  String get tableComment => '資料表註解';

  @override
  String get storageEngine => '儲存引擎';

  @override
  String get tableCollation => '資料表定序';

  @override
  String get rowFormat => '列格式';

  @override
  String get createOrReplace => '建立或取代';

  @override
  String get dropSelectedObject => '刪除選定物件';

  @override
  String get addColumn => '新增欄';

  @override
  String get editColumnProperties => '編輯欄屬性';

  @override
  String get tableProperties => '資料表屬性';

  @override
  String get triggerDefinition => '觸發程序定義';

  @override
  String get createTable => '建立資料表';

  @override
  String get viewDefinition => '檢視表定義';

  @override
  String get routineDefinition => '常式定義';

  @override
  String get chooseExistingObject => '選擇現有物件';

  @override
  String get nullable => '允許 NULL';

  @override
  String get removeIdentity => '移除識別';

  @override
  String get generatedAlways => '一律產生';

  @override
  String get generatedByDefault => '預設產生 / 自動遞增';

  @override
  String get loggedTable => '記錄日誌的資料表';

  @override
  String get unloggedTable => '不記錄日誌的資料表';

  @override
  String get orderedPrimaryKeyColumns => '有序主索引鍵欄';

  @override
  String get orderedColumns => '有序欄';

  @override
  String get ordinaryIndex => '一般索引';

  @override
  String get uniqueIndex => '唯一索引';

  @override
  String get primaryKey => '主索引鍵';

  @override
  String get uniqueConstraint => '唯一條件約束';

  @override
  String get foreignKey => '外部索引鍵';

  @override
  String get checkConstraint => 'CHECK 條件約束';

  @override
  String get immediateChecking => '立即檢查';

  @override
  String get deferrableChecking => '可延遲檢查';

  @override
  String get initiallyImmediate => '初始立即';

  @override
  String get initiallyDeferred => '初始延遲';

  @override
  String get referencedTable => '參照的資料表';

  @override
  String get orderedReferencedColumns => '依對應順序排列的參照欄';

  @override
  String get objectDefinitionEditor => '原生物件定義 SQL 編輯器';

  @override
  String get onDelete => '刪除時';

  @override
  String get onUpdate => '更新時';

  @override
  String get stay => '留下';

  @override
  String get saveSqlClose => '儲存 SQL 並關閉';

  @override
  String get discardSqlClose => '捨棄 SQL 並關閉';

  @override
  String get closeBusyData => '關閉 BusyData';

  @override
  String get saveDraftsClose => '儲存草稿並關閉';

  @override
  String get closeWithoutRecovery => '不復原直接關閉';

  @override
  String get recoveryFailed => '復原失敗';

  @override
  String get discardFailedSaveClose => '捨棄失敗的儲存並關閉';

  @override
  String get closeWithoutSavingRecovery => '不儲存復原資料直接關閉';

  @override
  String get disableSqlRecovery => '停用 SQL 復原';

  @override
  String get historyPrivacy => '歷程隱私';

  @override
  String get enableSqlRetention => '啟用 SQL 保留';

  @override
  String get disableSqlRetention => '停用 SQL 保留';

  @override
  String get clearHistory => '清除歷程';

  @override
  String get deleteHistoryEntry => '刪除歷程記錄';

  @override
  String get deleteSelected => '刪除所選';

  @override
  String get saveRetention => '儲存保留設定';

  @override
  String get retentionDays => '保留天數';

  @override
  String get sqlTextRetained => '已保留 SQL 文字';

  @override
  String get sqlTextDisabled => 'SQL 文字已停用';

  @override
  String get openHistoryQuery => '在新 SQL 分頁開啟';

  @override
  String get caCertificateFile => 'CA 憑證檔案';

  @override
  String get clientCertificateFile => '用戶端憑證檔案';

  @override
  String get clientKeyFile => '用戶端金鑰檔案';

  @override
  String get directConnection => '直接連線';

  @override
  String get sshTunnel => 'SSH 通道';

  @override
  String get sshHost => 'SSH 主機';

  @override
  String get sshPort => 'SSH 連接埠';

  @override
  String get sshUser => 'SSH 使用者';

  @override
  String get reviewedKnownHosts => '已審查的 known_hosts 檔案';

  @override
  String get reviewSshKey => '審查 SSH 主機金鑰';

  @override
  String get changedSshKey => 'SSH 主機金鑰已變更';

  @override
  String get verifyFingerprint => '信任之前，請獨立驗證此指紋。';

  @override
  String get selectedKeyPassword => '所選金鑰或密碼';

  @override
  String get selectedAgentIdentity => '所選 SSH 代理程式身分';

  @override
  String get selectedAgentSocket => '所選 Linux 代理程式通訊端 / Windows 具名管道';

  @override
  String get selectedKeyFingerprint => '所選金鑰指紋 · SHA256:…';

  @override
  String get selectedPrivateKey => '所選私密金鑰（選用）';

  @override
  String get sshPassword => 'SSH 密碼';

  @override
  String get keyPassphrase => '金鑰密碼片語';

  @override
  String get connectionTimeout => '連線逾時 · 1–120 秒';

  @override
  String get sqlTimeout => 'SQL 執行/擷取期限 · 1–3600 秒（0 = 60）';

  @override
  String get schemasEquivalent => '擷取的結構描述等效。';

  @override
  String get migrationComplete => '移轉涵蓋擷取的受支援差異。';

  @override
  String get migrationPartial => '部分移轉；仍有不支援的差異。';

  @override
  String get differencesLimited => '差異顯示有限。請審查完整的已儲存快照和產生的 SQL。';

  @override
  String get absent => '不存在';

  @override
  String get definitionPreviewLimited => '定義預覽有限；請使用原始快照查看完整依據。';

  @override
  String get migrationBatchNote => 'SQL 是按相依順序排列的單一批次。選擇單一物件用於檢查，不會選擇要套用的陳述式。';

  @override
  String get unsupportedLabel => '不支援';

  @override
  String get differenceAdded => '已新增';

  @override
  String get differenceRemoved => '已移除';

  @override
  String get differenceChanged => '已變更';

  @override
  String get selectHistoryEntry => '選擇歷程記錄';

  @override
  String get searchSqlTarget => '搜尋 SQL 或目標';

  @override
  String get closeSqlTab => '關閉 SQL 分頁';

  @override
  String get historyMetadataRetained => '狀態和目標中繼資料仍保留在歷程中。';

  @override
  String get historyPreviewNote => '僅預覽。在新 SQL 分頁開啟以取得保留的文字。';

  @override
  String get selected => '已選取';

  @override
  String get authReviewNote =>
      '套用前請審查準確的使用者或角色和目標。認證資料絕不會放入 SQL 文件或歷程。現有連線和儲存的密碼保持獨立。';

  @override
  String get createLogin => '建立登入帳戶';

  @override
  String get createRole => '建立不可登入角色';

  @override
  String get setPassword => '設定密碼';

  @override
  String get preventLogin => '阻止新登入';

  @override
  String get allowLogin => '允許新登入';

  @override
  String get dropPrincipal => '刪除使用者或角色';

  @override
  String get principalName => '準確的使用者或角色名稱';

  @override
  String get accountHost => '準確的帳戶主機（萬用字元會擴大登入範圍）';

  @override
  String get newPassword => '新密碼';

  @override
  String get repeatPassword => '重複新密碼';

  @override
  String get reviewAccount => '審查帳戶操作';

  @override
  String get passwordsMismatch => '請兩次輸入相同的非空密碼';

  @override
  String get accountSubmitFailed => '無法提交帳戶操作。請檢查目標、驗證原則和資料庫權限。';

  @override
  String get privilegeReviewNote => '檢查直接授予的權限；產生的 SQL 仍需要執行審查。';

  @override
  String get inspectionLimited => '每節最多 500 列。請縮小搜尋範圍；空節並不能證明沒有有效存取權限。';

  @override
  String get findPrincipal => '尋找使用者 / 角色名稱';

  @override
  String get searchPrincipals => '搜尋使用者和角色';

  @override
  String get choosePrincipal => '選擇使用者或角色';

  @override
  String get inspectGrants => '檢查所選權限';

  @override
  String get tablePrivileges => '資料表 / 檢視權限';

  @override
  String get schemaPrivileges => '結構描述權限';

  @override
  String get databasePrivileges => '資料庫權限';

  @override
  String get roleMembership => '角色成員資格';

  @override
  String get defaultRole => '預設角色啟用';

  @override
  String get chooseGrantRole => '選擇要授予 / 撤銷的角色';

  @override
  String get tableView => '資料表 / 檢視';

  @override
  String get explicitPrivileges => '明確權限（逗號分隔）';

  @override
  String get setDefaultRole => '設定所選預設角色';

  @override
  String get clearDefaultRole => '清除預設角色';

  @override
  String get grantAccess => '授予存取';

  @override
  String get revokeAccess => '撤銷存取';

  @override
  String get withoutDelegation => '不委派';

  @override
  String get allowDelegation => '允許接收者授予其他人';

  @override
  String get readonlyChanges => '此設定檔為唯讀。變更需要明確可寫的工作階段。';

  @override
  String get createPrincipal => '建立使用者 / 角色';

  @override
  String get manageAuthentication => '管理所選驗證';

  @override
  String get openPrivilegeSql => '開啟權限 SQL 供審查';

  @override
  String get inspectPrincipalFirst => '擬定變更前請檢查所選使用者或角色';

  @override
  String get accountAuthentication => '帳戶驗證';

  @override
  String get schema => '結構描述';

  @override
  String get available => '可用';

  @override
  String get availableEmpty => '可用 · 資料為空';

  @override
  String get limitedVisibility => '可見性或範圍有限';

  @override
  String get permissionDenied => '權限被拒絕';

  @override
  String get unavailable => '不可用';

  @override
  String get profileDisabled => '由設定檔停用';

  @override
  String get unknownState => '未知';

  @override
  String get inspecting => '正在檢查…';

  @override
  String get refreshCapabilities => '重新整理功能';

  @override
  String get staleRefresh => '已過期 · 連線後重新整理';

  @override
  String get staleContext => '已過期 · 連線或內容變更後重新整理';

  @override
  String get partialTreeLimit => '部分 · 已達到樹狀上限；請縮小資料庫物件搜尋範圍';

  @override
  String get schemaComparison => '結構描述比較';

  @override
  String get searchTable => '搜尋資料表';

  @override
  String get focusObject => '聚焦';

  @override
  String get exportSvg => '匯出 SVG';

  @override
  String get exportPng => '匯出 PNG';

  @override
  String get diagramNotes => '圖表備註（包含在 SVG 中）';

  @override
  String get openNotes => '開啟備註';

  @override
  String get saveNotes => '儲存備註';

  @override
  String get newSnippet => '新增片段';

  @override
  String get snippetName => '片段名稱';

  @override
  String get saveSnippet => '儲存片段';

  @override
  String get deleteSnippet => '刪除已儲存片段';

  @override
  String get insertSnippet => '插入 SQL 文件';

  @override
  String get snippetEditor => 'SQL 片段編輯器';

  @override
  String get snippetsNote => '將已儲存的本機 SQL 插入所選文件，可復原。執行仍需明確操作。';

  @override
  String get level => '層級';

  @override
  String get expanded => '已展開';

  @override
  String get collapsed => '已摺疊';

  @override
  String get treeLevel => '層級';

  @override
  String get retainedView => '保留檢視';

  @override
  String get tableQuerySnapshot => '資料表查詢快照';

  @override
  String get originalResultNote => '原始保留結果；分頁和檢查不會執行 SQL';

  @override
  String get tableFilterNote => '套用會提交新的已審查資料庫查詢。舊快照仍然保留。';

  @override
  String get retainedFilterNote => '固定快照內所有已取得列。不會重新執行 SQL。保留值排序可能與資料庫定序規則不同。';

  @override
  String get retainedRowNote => '請選擇已取得結果中的列。不會重新執行 SQL。';

  @override
  String get copyLimitNote => '複製最多 10,000 個儲存格；更大範圍請匯出保留資料。';

  @override
  String get inlineValueLimit => '儲存格編輯支援 8KiB 值';

  @override
  String get editContextChanged => '來源工作階段或編輯內容已變更；暫存前請檢查或重新整理評估';

  @override
  String get editAssessmentUnavailable => '無法評估可編輯性；工作階段閒置後請重新整理評估';

  @override
  String get rowChangeReverted => '待處理列變更已復原；資料庫未變';

  @override
  String get sqlCopyRequiresMetadata => 'SQL 複製需要後端及其保留型別中繼資料。';

  @override
  String get exportFullValue => '匯出完整保留值';

  @override
  String valueExportReview(String bytes, String path) {
    return '將 $bytes 位元組儲存到 $path？將取代現有內容。不會重新執行 SQL。';
  }

  @override
  String get goToRetainedRow => '移至保留列';

  @override
  String get row => '列';

  @override
  String get go => '移至';

  @override
  String get retryRows => '重試保留列';

  @override
  String get previousRows => '上一批列';

  @override
  String get nextRows => '下一批列';

  @override
  String get firstWindow => '首個保留視窗';

  @override
  String get lastWindow => '最後取得的視窗';

  @override
  String get setNull => '設定 NULL';

  @override
  String copyFormat(String format) {
    return '複製 $format';
  }

  @override
  String get textValue => '文字';

  @override
  String get sqlValues => 'SQL 值';

  @override
  String get rowSelection => '列選取';

  @override
  String selectRow(String row) {
    return '選取列 $row';
  }

  @override
  String columnHeader(String column) {
    return '欄 $column';
  }

  @override
  String get pendingChange => '待處理變更';

  @override
  String get readonlyCell => '唯讀儲存格';

  @override
  String get editableCell => '可編輯儲存格';

  @override
  String get loadValueFirst => '請先載入此保留值';

  @override
  String get editUnavailable => '不可編輯';

  @override
  String get editCell => '編輯儲存格';

  @override
  String get unsupportedEditValue => '此保留值僅支援檢查';

  @override
  String bytesCount(String bytes) {
    return '$bytes 位元組';
  }

  @override
  String get problems => '問題';

  @override
  String get ownedSessions => '所屬工作階段';

  @override
  String get noProblems => '沒有記錄的問題';

  @override
  String get duplicateConnection => '複製連線';

  @override
  String get deleteConnection => '刪除連線';

  @override
  String deleteConnectionReview(String name) {
    return '刪除 $name？現有實體工作階段保持原始設定。';
  }

  @override
  String get unresolvedSessions => '未解決工作階段';

  @override
  String get disconnectSessionNote =>
      '請先處理作用中作業和交易。中斷會影響此實體工作階段的所有用戶端；不會提交交易或重播 SQL。未知結果仍然未知。';

  @override
  String get transferSettingsChanged => '設定已變更；請重新審查';

  @override
  String get transferReviewReady => '審查就緒；開始前核對目標、範圍、對應和檔案';

  @override
  String get sourcePreviewNotice => '來源預覽；未匯入資料庫列';

  @override
  String get transferRequiresReview => '請先審查此確切傳輸';

  @override
  String get transferSubmittedNotice => '已提交；取消不會撤銷已確認提交或已發佈檔案';

  @override
  String get sqlExportExecutionNote => '新的已審查 SQL 執行';

  @override
  String get retainedExportSnapshotNote => '已取得快照；不會執行 SQL';

  @override
  String get restorePartialCommitNote => '還原可能部分提交。取消不會撤銷還原。';

  @override
  String get sourcePreviewLimit => '來源預覽；最多 20 列';

  @override
  String get importBatchSafetyNote => '錯誤或取消會保留先前的批次提交。傳送前再次驗證來源雜湊和所選不可變材料。';

  @override
  String get nullMarkerLiteralNote => '無引號 NULL 標記；有引號時為文字文本';

  @override
  String immutableSourceHash(String hash) {
    return '不可變來源 SHA-256：$hash';
  }

  @override
  String sourceColumnLabel(String column) {
    return '來源欄 $column';
  }

  @override
  String previewRowLabel(String row, String column, String value) {
    return '預覽列 $row，$column：$value';
  }

  @override
  String get transferCancellationNotice => '已要求取消；等待確認';

  @override
  String transferProgress(String processed, String committed, String rejected) {
    return '$processed 已處理 · $committed 已提交 · $rejected 已拒絕';
  }

  @override
  String get importAtomicPolicy => '所有列在一個交易中';

  @override
  String get importBatchPolicy => '按批次提交；遇錯停止';

  @override
  String get importSkipPolicy => '跳過無效列；按批次提交';

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
    return '確認/連線：$operations\n未儲存文件：$documents\n正在儲存：$saves\n待處理編輯：$edits\n作用中作業：$jobs\n需清理交易：$transactions\n未知操作結果：$unknown\n不確定工作階段：$sessions';
  }

  @override
  String get closeDraftSaved => 'SQL 草稿將儲存到本機。';

  @override
  String get closeDraftLost => '復原已關閉；未儲存的 SQL 和物件設計將遺失。';

  @override
  String get closeDesignRecovery => '物件設計使用私密有界復原。重新開啟後請明確連線並檢查中繼資料。';

  @override
  String get closeCleanupReview =>
      '關閉最後的工作階段擁有者會要求取消、回復已確認交易並中斷。未知結果仍然未知；關閉絕不會提交或重播 SQL。';

  @override
  String get closeSharedSession => '其他用戶端保留共用實體工作階段。';

  @override
  String get closeStagedRecovery => '待處理變更需要確認私密復原、明確重新連線和新的審查。';

  @override
  String get closeRecoveryLoss => '未能儲存文件和版面配置。關閉可能遺失 SQL 和變更；現有檔案及復原資料仍會保留。';

  @override
  String get closeWaitNotice => '關閉前請等待操作確認和連線清理。';

  @override
  String get saveFailedNotice => 'SQL 儲存失敗。請保留已修改 SQL 或明確捨棄。';

  @override
  String get closeCleanupFailed => '後端清理失敗；BusyData 保持開啟。';

  @override
  String get closeBackendUnverified => '後端狀態未驗證；可能仍有待處理工作。';

  @override
  String historyRetainSqlReview(String days) {
    return 'SQL 可能包含秘密。儲存文字 $days 天？';
  }

  @override
  String get historyStopSqlReview => '停止儲存 SQL 並從現有歷程中刪除？';

  @override
  String get historyClearReview => '清除所有歷程？作用中作業結束時可能記錄結果。';

  @override
  String get historyDeleteReview => '刪除選取的歷程項目？';

  @override
  String get historyRetentionRange => '保留時間必須為 1–3650 天';

  @override
  String get enableSqlHistory => '啟用 SQL 歷程';

  @override
  String get stopSqlHistory => '停止保留 SQL';

  @override
  String get recoveryDiscardReview => '捨棄復原記錄？請先核對未知結果；捨棄不會撤銷已提交變更。';

  @override
  String closeSqlSummary(String unsaved, String edits, String jobs) {
    return '未儲存 SQL：$unsaved\n待處理變更：$edits\n作用中作業：$jobs';
  }

  @override
  String get recoveryStayOpen => '復原失敗。BusyData 保持開啟；未儲存的工作仍被保留。';

  @override
  String get commitUncertaintyNote => '網路故障可能使提交結果未知。絕不要自動重試。';

  @override
  String get closeObjectDesignDiscard => '將捨棄未儲存的物件設計欄位。請先產生並儲存 SQL 以保留設計。';

  @override
  String get savePrivateDrafts => '儲存私密復原草稿';

  @override
  String get noPrivateDrafts => '不儲存復原草稿';

  @override
  String shortcutField(String command) {
    return '$command 快速鍵';
  }

  @override
  String get shortcutInvalid => '請使用未指派給其他操作的有效快捷鍵。F6 和 Shift+F6 已保留。';

  @override
  String get disableRecoveryReview =>
      '刪除本機 SQL、設計及暫存變更的復原？未儲存工作保持開啟，但當機可能遺失。請先核對未知結果。';

  @override
  String get preferencesSaved => '設定已儲存';

  @override
  String get sharingSessionReview =>
      '此查詢與列出的用戶端共用所指定的實體工作階段、交易、暫時物件及設定。關閉一個用戶端會保留其他用戶端。';

  @override
  String get recoveryReconcileFirst => '關閉復原前請核對正在套用或未知的變更。僅透過明確的個別審查捨棄復原記錄。';

  @override
  String get enterSearchText => '輸入搜尋文字';

  @override
  String get noSearchMatches => '無符合項目';

  @override
  String searchMatchCount(String position, String total) {
    return '第 $position 項，共 $total 項';
  }

  @override
  String get formatSqlChanged => 'SQL 或目標已變更。原始 SQL 已保留；請重新要求格式預覽。';

  @override
  String get formatSqlUnavailable => '語法不完整、不支援或超出分析限制，無法格式化。原始 SQL 已保留。';

  @override
  String get stageChange => '暫存變更';

  @override
  String pendingChangesCount(String count) {
    return '$count 項待處理變更；經審查套用前資料庫保持不變。';
  }

  @override
  String discardChangesCount(String count) {
    return '捨棄 $count 項待處理變更？不會提交資料庫操作。';
  }

  @override
  String get recoveryNoExecution => '復原不會連線、執行來源 SQL、恢復交易或重播變更。未知及已提交紀錄無法再次套用。';

  @override
  String get recoveredDesign => '設計已復原。請明確連線並檢查目前中繼資料後再產生審查。復原未取得 SQL 或中繼資料。';

  @override
  String get retainedUnavailable => '保留資料無法使用。已儲存的 SQL 和私密復原仍在本機。';

  @override
  String get activityFingerprintNote => '提交前會重新驗證所選活動的指紋。寫入結果可能未知。';

  @override
  String replaceFileReview(String path) {
    return '取代已審查的檔案 $path？目標變更需要重新審查。';
  }

  @override
  String get diagramPngSaved => '圖表 PNG 已儲存。長備註最多顯示六行。';

  @override
  String get editTargetChanged => '編輯目標已變更。暫存前請重新開啟列編輯器。';

  @override
  String affectedRowCount(String count) {
    return '受影響的列數：$count';
  }

  @override
  String get zoomIn => '放大';

  @override
  String get zoomOut => '縮小';

  @override
  String get resetView => '重設檢視';

  @override
  String get diagramKeys => '方向鍵平移；+ 和 - 縮放；Home 重設檢視。';

  @override
  String get explorerConnected => '資料庫總管已連線';

  @override
  String get explorerDisconnected => '資料庫總管未連線';

  @override
  String querySessionCount(String count) {
    return '查詢工作階段 $count';
  }

  @override
  String get metadataColumn => '欄';

  @override
  String get metadataPosition => '位置';

  @override
  String get metadataUnique => '唯一';

  @override
  String get metadataJdbcType => 'JDBC 類型';

  @override
  String get metadataAutoIncrement => '自動遞增';

  @override
  String get metadataReferencedColumn => '參照欄';

  @override
  String get metadataComment => '註解';

  @override
  String get metadataType => '類型';

  @override
  String get metadataEvent => '事件';

  @override
  String get metadataSpecificName => '原生特定識別碼';

  @override
  String get metadataOptions => '選項';

  @override
  String get metadataInheritance => '繼承';

  @override
  String get metadataDefinitionCaptured => '已擷取的原生定義';

  @override
  String get metadataDefinitionUnavailable => '擷取的中繼資料中無法提供定義';

  @override
  String get metadataDefinitionUnsupported => '擷取的物件沒有受支援的原生定義';

  @override
  String get connections => '連線';

  @override
  String get noConnections => '尚無連線';

  @override
  String get startTitle => '連線至資料庫';

  @override
  String get startDescription =>
      '連線至 PostgreSQL、MySQL 或 MariaDB，瀏覽物件、管理資料並執行查詢。';

  @override
  String get savedStartTitle => '選擇連線';

  @override
  String get savedStartDescription => '在資料庫總管中連線至已儲存的連線，瀏覽物件並執行查詢。';

  @override
  String get noConnection => '無連線';

  @override
  String queryTitle(int number) {
    return '查詢 $number';
  }

  @override
  String get sessionMenu => '工作階段';

  @override
  String get noFilterMatches => '沒有相符的連線或已載入物件';

  @override
  String get activityState => '狀態';

  @override
  String get activityWait => '等待';

  @override
  String get generalSettings => '一般';

  @override
  String get optionsSettings => '選項';

  @override
  String get host => '主機';

  @override
  String get databaseSystem => '資料庫系統';

  @override
  String get passwordStorage => '密碼儲存';

  @override
  String get environmentLabel => '環境';

  @override
  String get readOnlySettings => '唯讀原則';

  @override
  String get tlsPolicy => 'TLS 原則';

  @override
  String get sshConnection => 'SSH 連線';

  @override
  String get sshAuthentication => 'SSH 驗證';

  @override
  String get connectionTestAction => '測試連線';

  @override
  String get details => '詳細資訊';

  @override
  String get copyDetails => '複製詳細資訊';

  @override
  String get retry => '重試';

  @override
  String get filterCellValue => '依此值篩選';

  @override
  String get connectsWhenRun => '執行時連線';

  @override
  String get connectionSaving => '儲存…';

  @override
  String get connectionConnecting => '連線…';

  @override
  String get connectionCancelling => '取消…';

  @override
  String get connectionSettingsChanged => '設定已變更。請重新測試此版本。';

  @override
  String get connectionTestChanged => '設定已變更。請重新測試此版本。';

  @override
  String get connectionRequired => '必填';

  @override
  String get connectionCorrectFields => '請檢查標出的設定。';

  @override
  String get connectionHostname => '主機 · 請檢查標出的設定。';

  @override
  String get connectionSshHostname => 'SSH · 主機 · 請檢查標出的設定。';

  @override
  String get connectionMaxLength => '名稱 ≤ 256';

  @override
  String get connectionTlsHelp => 'TLS · 主機 · SSH/SSL. 請檢查標出的設定。';

  @override
  String get connectionTlsReview => 'TLS · 主機 · SSH/SSL. 請檢查標出的設定。';

  @override
  String get connectionStorageUnavailable => '密碼儲存: 不可用. 密碼 · 永不.';

  @override
  String get connectionHostReviewed => '主機 · 信任僅適用於此設定檔和此精確端點。';

  @override
  String get connectionSshReviewing => 'SSH · 審查 SSH 主機金鑰…';

  @override
  String get connectionFailureAuthentication => '失敗 · 驗證 · 一般. 請檢查標出的設定。';

  @override
  String get connectionFailureTls => '失敗 · TLS · SSH/SSL. 請檢查標出的設定。';

  @override
  String get connectionFailureSshKey => '失敗 · 審查 SSH 主機金鑰. 請檢查標出的設定。';

  @override
  String get connectionFailureEndpoint => '失敗 · 主機 · 連接埠. 請檢查標出的設定。';

  @override
  String get connectionFailureCancelled => '已取消';

  @override
  String get connectionFailureSettings => '失敗 · 一般. 請檢查標出的設定。';

  @override
  String get connectionFailureAccess => '失敗 · 資料表 / 檢視權限. 請檢查標出的設定。';

  @override
  String get connectionFailureUnavailable => '失敗 · 主機 · TLS · SSH. 請檢查標出的設定。';

  @override
  String get connectionFailureTimeout => '失敗 · 連線逾時 · 1–120 秒. 請檢查標出的設定。';

  @override
  String get connectionFailureUnknown => '失敗 · 一般 · TLS · SSH. 請檢查標出的設定。';

  @override
  String connectionNumber(int min, int max) {
    return '請輸入 $min 到 $max 之間的整數';
  }

  @override
  String connectionSavedFailure(String name) {
    return '連線已儲存：$name。連線嘗試失敗。 ';
  }

  @override
  String get backendBusy => '後端忙碌。請等待目前請求完成，然後重試。';

  @override
  String rpcRequestUnconfirmed(String code) {
    return '請求未獲確認（RPC $code）。';
  }

  @override
  String get operationUnconfirmed => '無法完成操作。';

  @override
  String get connectionFailureTlsMaterial =>
      'TLS 資料無法使用或無效。請在 SSH/SSL 中檢查信任來源和用戶端金鑰。';

  @override
  String get managerTitle => '資料來源與驅動程式';

  @override
  String get sourceListTitle => '資料來源';

  @override
  String get driverLabel => '驅動程式';

  @override
  String get connectionTypeLabel => '連線類型';

  @override
  String get defaultTcp => '預設 (TCP)';

  @override
  String get authenticationLabel => '驗證';

  @override
  String get userPasswordAuth => '使用者與密碼';

  @override
  String get neverStorage => '永不';

  @override
  String get initialDatabaseLabel => '初始資料庫';

  @override
  String get useSshTunnel => '使用 SSH 通道';

  @override
  String get sshConfigurationLabel => 'SSH 組態';

  @override
  String get createSshConfig => '<建立組態>';

  @override
  String get copySshSettings => '複製 SSH 設定';

  @override
  String get localPortLabel => '本機連接埠';

  @override
  String get dynamicPortLabel => '<動態>';

  @override
  String get useSsl => '使用 SSL';

  @override
  String get useTruststore => '使用信任存放區';

  @override
  String get clientKeyPasswordLabel => '用戶端金鑰密碼';

  @override
  String get modeLabel => '模式';

  @override
  String get requireTls => '要求';

  @override
  String get verifyCa => '驗證 CA';

  @override
  String get fullVerification => '完整驗證';

  @override
  String get connectionSection => '連線';

  @override
  String get configurationApplied => '已套用組態';

  @override
  String get noOtherSshConfig => '其他資料來源沒有 SSH 組態。';

  @override
  String get generatedUrlHelp => '產生的唯讀 JDBC 位址。';

  @override
  String get tlsDriverDefaultHelp => 'SSL 尚未設定；使用隨附驅動程式的預設設定。';

  @override
  String get tlsClientKeyHelp => 'PEM 金鑰：PKCS#8 或 OpenSSL；支援加密或未加密金鑰。';

  @override
  String get legacyMariaTrustHelp => '保留現有驅動程式驗證。選擇信任來源以明確設定根憑證。';

  @override
  String get metadataStartValue => '起始值';

  @override
  String get metadataMinimumValue => '最小值';

  @override
  String get metadataMaximumValue => '最大值';

  @override
  String get metadataIncrement => '增量';

  @override
  String get metadataCycle => '循環';

  @override
  String get metadataCacheSize => '快取大小';

  @override
  String get metadataLastValue => '最後值';

  @override
  String get sequences => '序列';

  @override
  String get namespaceSelection => '選擇命名空間';

  @override
  String get namespaceSelectionNotice => '選擇控制中繼資料內省。查詢主控台保留其執行內容。';

  @override
  String get allNamespaces => '所有命名空間';

  @override
  String get defaultNamespace => '預設';

  @override
  String get namespacePattern => '名稱模式（規則運算式）';

  @override
  String namespaceCount(int selected, int known) {
    return '$known 中的 $selected';
  }

  @override
  String get previousPage => '上一頁';

  @override
  String get patternRejected => '模式無效或超出工作限制。保留先前的選擇。';

  @override
  String get namespaceNotSelected => '未選擇此命名空間進行內省';

  @override
  String get newMenu => '新增';

  @override
  String get queryConsoles => '查詢主控台';

  @override
  String get viewOptions => '檢視選項';

  @override
  String get quickDocumentation => '快速文件';

  @override
  String get showEmptyGroups => '顯示空群組';

  @override
  String get speedSearch => '快速搜尋';

  @override
  String get speedSearchScope => '僅搜尋已展開且已載入的節點。';

  @override
  String get newSourceFolder => '新增資料來源資料夾';

  @override
  String get renameSourceFolder => '重新命名資料夾';

  @override
  String get moveToFolder => '移動至資料夾';

  @override
  String get moveUp => '上移';

  @override
  String get moveDown => '下移';

  @override
  String get folderMustBeEmpty => '移除此資料夾前，請移出其中的資料來源和資料夾。';

  @override
  String get newVirtualView => '新增虛擬檢視';

  @override
  String get editVirtualDefinition => '編輯本機定義';

  @override
  String get unboundVirtualView => '未繫結的虛擬檢視';

  @override
  String get localVirtualViewNotice =>
      '本機 SQL 定義。儲存不會執行 SQL 或建立伺服器檢視。執行使用一般 SQL 審查與獨立主控台。';

  @override
  String get rebindVirtualView => '將本機定義繫結於此處';

  @override
  String get sourceFolderName => '資料夾名稱';

  @override
  String get sourceFolderPathNotice => '使用 / 建立巢狀資料夾。';

  @override
  String get topLevel => '最上層';

  @override
  String get virtualViewName => '虛擬檢視名稱';

  @override
  String get virtualViewSql => '虛擬檢視 SQL 定義';

  @override
  String get virtualViews => '虛擬檢視';

  @override
  String get revealInExplorer => '在資料庫總管中顯示';

  @override
  String get objectNotFound => '在此命名空間中找不到物件。請重新整理中繼資料或檢查權限。';

  @override
  String get objectHiddenByFilter => '目前的檢視篩選器隱藏了此物件。';

  @override
  String get revealFilterNotice => '物件查找縮小了此頁範圍，因此省略整個群組的總數。';

  @override
  String get clearObjectFilter => '清除物件查找';

  @override
  String get compareStructure => '比較結構';

  @override
  String get selectTwoCompatibleObjects => '按住 Ctrl 按一下以選取兩個相容的資料表。';

  @override
  String get scopedComparisonRestriction =>
      '限定範圍的比較要求一般資料表具有相同的原生名稱、結構描述和引擎。不支援其他類型或重新命名比對。';

  @override
  String get groupNamespaces => '分組顯示資料庫和結構描述';

  @override
  String get groupSchemaObjects => '分組顯示結構描述物件';

  @override
  String get groupTableElements => '分組顯示資料表元素';

  @override
  String get sortAlphabetically => '依字母順序排序';

  @override
  String get showVirtualObjects => '顯示虛擬物件';

  @override
  String get showObjectComments => '顯示物件註解';

  @override
  String get objectTypeFilter => '物件類型篩選器';

  @override
  String get partitionedTable => '分割資料表';

  @override
  String get foreignTable => '外部資料表';

  @override
  String get materializedView => '具體化檢視';

  @override
  String get functionObject => '函式';

  @override
  String get procedureObject => '預存程序';

  @override
  String get sqlSymbolUnavailable =>
      '無法安全解析游標處的持續性物件。請連接此主控台，並使用常值和註解以外的資料表或檢視參照。';

  @override
  String get sqlSymbolAmbiguous => 'SQL 物件參照不明確。請限定其命名空間或選取確切的資料庫物件。';

  @override
  String get deactivateSource => '停用資料來源';

  @override
  String get functions => '函式';

  @override
  String get procedures => '預存程序';

  @override
  String get separateProceduresFunctions => '分開顯示預存程序與函式';

  @override
  String get renameVirtualView => '重新命名虛擬檢視';

  @override
  String get metadataPersistentScope => '僅顯示持久物件；暫存物件和工作階段本機物件仍在主控台導覽中。';

  @override
  String get metadataSessionScope => '僅顯示持久物件；執行後請重新整理主控台本機物件。';

  @override
  String get metadataLimitScope => '已達到中繼資料限制。請縮小物件範圍。';

  @override
  String get completeColumnMetadataRequired => '匯入或暫存變更前需要完整的欄位中繼資料。';

  @override
  String resizeColumn(String name) {
    return '調整資料行 $name 的寬度';
  }

  @override
  String get keyboardShortcutsHeading => '鍵盤快速鍵';

  @override
  String sqlEditorLabel(String title) {
    return 'SQL 編輯器 $title';
  }

  @override
  String get editorResultsDivider => '編輯器與結果分隔線';

  @override
  String editorExtent(String percent) {
    return '編輯器佔 $percent 百分比';
  }

  @override
  String get largerEditor => '擴大編輯器';

  @override
  String get smallerEditor => '縮小編輯器';

  @override
  String get explorerWidthDivider => '總管寬度分隔線';

  @override
  String get widerExplorer => '加寬總管';

  @override
  String get narrowerExplorer => '縮窄總管';

  @override
  String explorerExtent(String width) {
    return '寬 $width 像素';
  }

  @override
  String planTextPage(String start, String end, String total) {
    return '第 $start–$end 個，共 $total 個 UTF-16 單元';
  }

  @override
  String get dropDesignedColumn => '刪除資料行';

  @override
  String get liveCatalogLabel => '目前目錄';

  @override
  String get liveSchemaLabel => '目前結構描述';

  @override
  String get searchPathLabel => '搜尋路徑';

  @override
  String get physicalSessionLabel => '實體工作階段';

  @override
  String queryTimeoutDetail(String seconds, String rows) {
    return '逾時：$seconds 秒 · 資料列限制：$rows';
  }

  @override
  String get saveFailedCloseTitle => 'SQL 儲存失敗 · 關閉 BusyData';

  @override
  String get createSection => '建立';

  @override
  String get newConnectionDescription => '設定資料庫連線';

  @override
  String get newQueryDescription => '在新查詢中撰寫 SQL';

  @override
  String get openSqlDescription => '開啟現有 SQL 文件';

  @override
  String get searchNoResults => '沒有相符的操作';

  @override
  String get actionsCategory => '操作';

  @override
  String get privateRecoveryCategory => '私人復原';

  @override
  String get shortcutRecordHelp => '請按快捷鍵。Escape 取消。F6 和 Shift+F6 保留用於面板導覽。';

  @override
  String get rowLimitInvalid => '請輸入 1 到 1,000,000 之間的列數上限。';

  @override
  String get errorPolicy => '執行出錯時';

  @override
  String get tlsEncrypted => '已加密';

  @override
  String get tlsUnencrypted => '未加密';

  @override
  String get tlsUnobserved => '未觀察到';

  @override
  String get encryptionVerificationNote => '加密並不證明已驗證憑證或主機名稱。';

  @override
  String get uniqueDesignedColumnName => '請使用唯一的欄名；新建資料表最多支援 128 欄';

  @override
  String activityBlockerUnavailable(String id) {
    return '阻擋工作階段 $id 已不可見；請重新整理並檢查資料庫權限';
  }

  @override
  String get sshChangedKeyReview => '取代此設定檔的繫結前，請獨立驗證變更後的金鑰。';

  @override
  String get sshProfileTrustBinding => '信任僅適用於此設定檔和此精確端點。';

  @override
  String get databaseTlsEvidence => 'TLS · 資料庫系統';

  @override
  String get sshAlgorithmLabel => 'SSH · 類型';

  @override
  String get sshFingerprintLabel => 'SHA-256';

  @override
  String get sshPreviousFingerprintLabel => '上一項 · SHA-256';

  @override
  String get sshReviewedLabel => '審查 SSH 主機金鑰';

  @override
  String get shortcutRecordAction => '錄製快捷鍵';

  @override
  String get fileFormatLabel => '檔案格式';

  @override
  String get encodingLabel => '編碼';

  @override
  String get importPolicyLabel => '匯入政策';

  @override
  String get mainMenu => '主選單';

  @override
  String get activityReplyTooLarge => '活動回應超出檢查器限制。';

  @override
  String get activityListLimited => '清單受限；請使用明確的 SQL 檢查較小範圍的目標。';

  @override
  String get activitySelectionChanged => '所選活動已結束或發生變更。請先選取其目前識別資訊，再審查操作。';

  @override
  String connectionSavedDraftChanged(String name) {
    return '儲存時連線欄位已變更；設定已儲存：$name。連線前請檢查目前的值。';
  }

  @override
  String get sshReviewTargetChanged => 'SSH 審核目標已變更；請重新審核';

  @override
  String get appearance => 'Appearance';

  @override
  String get theme => 'Theme';

  @override
  String get systemTheme => 'System';

  @override
  String get lightTheme => 'Light';

  @override
  String get darkTheme => 'Dark';

  @override
  String get appLanguage => 'Language';

  @override
  String get systemLanguage => 'System';

  @override
  String get cut => 'Cut';

  @override
  String get paste => 'Paste';

  @override
  String get selectAll => 'Select all';

  @override
  String get noSelection => '沒有可用文字';

  @override
  String get clipboardEmpty => '剪貼簿中沒有文字';

  @override
  String get settingsDraftNotice => '執行與私密復原的變更尚未儲存。';

  @override
  String get documentsMenu => '文件';

  @override
  String get currentSql => '目前的 SQL';

  @override
  String get searchActionsHint => 'Search actions…';

  @override
  String get searchCurrentSqlHint => 'Search current SQL…';

  @override
  String get searchObjectsHint => 'Search database objects…';

  @override
  String get searchHistoryHint => 'Search query history…';

  @override
  String get metadataAttributes => '屬性';

  @override
  String get metadataSelectionUnavailable => '選取項目以檢視其擷取的屬性。先前的選取項目無法使用。';

  @override
  String get secureStorage => '系統安全儲存空間';

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
  String get metadataCacheWriteUnavailable => '無法儲存快取。目前的中繼資料仍可使用。';

  @override
  String get metadataCacheRebuiltVersion => '已為目前版本重建';

  @override
  String get metadataCacheRebuiltCorrupt => '快取發生錯誤後已重建';

  @override
  String get editSessionBusy => '此工作階段忙碌中。請等待目前的工作完成，再要求重新評估可編輯性。';

  @override
  String get editIdentityRequired => '編輯前，請選取完整的主索引鍵或不允許 NULL 的唯一識別鍵。';

  @override
  String get editColumnsReadOnly => '所有投影欄位均為產生的欄或唯讀欄位。';

  @override
  String get editResultNotReady => '請等待此保留結果完成，再要求重新評估可編輯性。';

  @override
  String get editProjectionUnsupported =>
      '編輯需要直接從單一基底資料表執行 SELECT，且每個基底欄位僅投影一次。';

  @override
  String get sqlInspectionDuplicateUsingColumn => 'JOIN USING 欄位重複';

  @override
  String get sqlInspectionUnresolvedUsingColumn => '某個運算元中缺少 JOIN USING 欄位';

  @override
  String get sqlInspectionAmbiguousUsingColumn => 'JOIN 共用欄位不明確';

  @override
  String get sqlInspectionOutputColumnCount => '宣告的輸出欄位數不符';

  @override
  String get sqlInspectionAmbiguousOverload => '常式多載不明確';

  @override
  String get sqlInspectionBooleanType => '布林運算式型別無效';

  @override
  String get sqlInspectionOperatorTypes => '運算子的運算元型別不相容';

  @override
  String get sqlInspectionArrayTypes => '陣列元素型別不相容';

  @override
  String get sqlInspectionCaseConditionType => 'CASE 條件型別不相容';

  @override
  String get sqlInspectionCaseResultTypes => 'CASE 結果型別不相容';

  @override
  String get sqlInspectionCoalesceTypes => 'COALESCE 引數型別不相容';

  @override
  String get sqlInspectionSetColumnCount => '集合運算的欄位數不符';

  @override
  String get sqlInspectionSetTypes => '集合運算的結果型別不相容';

  @override
  String get sqlInspectionRecursiveCteType => '遞迴 CTE 型別不符';
}
