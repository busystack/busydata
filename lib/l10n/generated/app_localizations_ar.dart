// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get cancel => 'إلغاء';

  @override
  String get windowMinimize => 'تصغير';

  @override
  String get windowMaximize => 'تكبير';

  @override
  String get windowRestore => 'استعادة';

  @override
  String get databaseExplorer => 'مستكشف قاعدة البيانات';

  @override
  String get databases => 'قواعد البيانات';

  @override
  String get newConnection => 'اتصال جديد';

  @override
  String get filterTree => 'تصفية الاتصالات والكائنات';

  @override
  String get treeFilterScope => 'يصفي كائنات الشجرة المحمّلة';

  @override
  String get searchObjects => 'البحث عن كائنات قاعدة البيانات';

  @override
  String get fileMenu => 'ملف';

  @override
  String get editMenu => 'تحرير';

  @override
  String get viewMenu => 'عرض';

  @override
  String get connectionMenu => 'اتصال';

  @override
  String get objectMenu => 'كائن';

  @override
  String get runMenu => 'خيارات التشغيل';

  @override
  String get commands => 'الأوامر';

  @override
  String get findCommand => 'البحث عن أمر';

  @override
  String get newSql => 'استعلام جديد';

  @override
  String get openSql => 'فتح SQL';

  @override
  String get openSqlFile => 'فتح ملف SQL';

  @override
  String get saveSql => 'حفظ SQL';

  @override
  String get closeTab => 'إغلاق علامة التبويب';

  @override
  String get openWorkspace => 'فتح مساحة العمل';

  @override
  String get saveWorkspace => 'حفظ مساحة العمل';

  @override
  String get settings => 'الإعدادات';

  @override
  String get findText => 'بحث';

  @override
  String get replaceText => 'استبدال';

  @override
  String get formatSql => 'تنسيق SQL';

  @override
  String get lineComments => 'تبديل تعليقات الأسطر';

  @override
  String get snippets => 'مقتطفات SQL';

  @override
  String get run => 'تشغيل';

  @override
  String get runStatement => 'تشغيل العبارة الحالية';

  @override
  String get runSelection => 'تشغيل التحديد';

  @override
  String get runScript => 'تشغيل البرنامج النصي';

  @override
  String get explain => 'شرح الخطة';

  @override
  String get explainAnalyze => 'شرح وتحليل';

  @override
  String get connect => 'اتصال';

  @override
  String get disconnect => 'قطع الاتصال';

  @override
  String get sessionDetails => 'تفاصيل الجلسة';

  @override
  String get beginTransaction => 'بدء معاملة';

  @override
  String get commitTransaction => 'تثبيت المعاملة';

  @override
  String get rollbackTransaction => 'التراجع عن المعاملة';

  @override
  String get enableAutoCommit => 'تفعيل التثبيت التلقائي';

  @override
  String get disableAutoCommit => 'تعطيل التثبيت التلقائي';

  @override
  String get outcomeUnknown => 'النتيجة غير معروفة';

  @override
  String get outcomeUnknownNote =>
      'ربما اكتملت العملية. لا يمكن لهذه الجلسة تنفيذ المزيد من SQL. لا تُعِد المحاولة تلقائيًا؛ تحقّق من النتيجة قبل بدء عمل جديد.';

  @override
  String get notConnected => 'غير متصل';

  @override
  String get autoCommit => 'تثبيت تلقائي';

  @override
  String get manualTransaction => 'معاملة يدوية';

  @override
  String get readOnlyPolicy => 'سياسة BusyData للقراءة فقط';

  @override
  String get data => 'البيانات';

  @override
  String get structure => 'البنية';

  @override
  String get results => 'النتائج';

  @override
  String get messages => 'الرسائل';

  @override
  String get plan => 'الخطة';

  @override
  String get changes => 'التغييرات';

  @override
  String get history => 'السجل';

  @override
  String get jobs => 'المهام';

  @override
  String get retainedResults => 'النتائج المحتفظ بها';

  @override
  String get recoverEdits => 'استعادة التغييرات المجهزة';

  @override
  String get applyAndCommit => 'تطبيق وتثبيت';

  @override
  String get inspectStructure => 'فحص البنية';

  @override
  String get openData => 'فتح البيانات';

  @override
  String get openDefinition => 'فتح التعريف';

  @override
  String get copyQualifiedName => 'نسخ الاسم المؤهل';

  @override
  String get refresh => 'تحديث';

  @override
  String get columns => 'الأعمدة';

  @override
  String get indexes => 'الفهارس';

  @override
  String get constraints => 'المفاتيح والقيود';

  @override
  String get foreignKeys => 'المفاتيح الخارجية';

  @override
  String get triggers => 'المشغلات';

  @override
  String get definition => 'التعريف';

  @override
  String get dependencies => 'التبعيات';

  @override
  String get connectionCapabilities => 'نظرة عامة على الاتصال';

  @override
  String get sessionsAndLocks => 'الجلسات والأقفال';

  @override
  String get usersAndRoles => 'المستخدمون والأدوار';

  @override
  String get saveSnapshot => 'حفظ لقطة المخطط';

  @override
  String get compareSchemas => 'مقارنة المخططات';

  @override
  String get objectDesigner => 'مصمم الكائنات';

  @override
  String get diagram => 'مخطط الكيانات والعلاقات';

  @override
  String get backup => 'نسخ احتياطي';

  @override
  String get restore => 'استعادة';

  @override
  String get importData => 'استيراد البيانات';

  @override
  String get exportRetained => 'تصدير البيانات المحتفظ بها';

  @override
  String get exportSql => 'تشغيل تصدير SQL';

  @override
  String get stageInsert => 'إدراج صف';

  @override
  String get stageUpdate => 'تحرير صف';

  @override
  String get stageDelete => 'حذف صف';

  @override
  String get discardChanges => 'تجاهل التغييرات المعلقة';

  @override
  String get disposeResult => 'تحرير البيانات المحتفظ بها';

  @override
  String get currentSchema => 'المخطط الحالي (المراد تغييره)';

  @override
  String get desiredSchema => 'المخطط المطلوب';

  @override
  String get applyTo => 'تطبيق على';

  @override
  String get loading => 'جارٍ التحميل';

  @override
  String get empty => 'لا توجد كائنات في هذا النطاق';

  @override
  String get more => 'المزيد';

  @override
  String get filter => 'تصفية';

  @override
  String get sort => 'فرز';

  @override
  String get selectTarget => 'اختيار اتصال';

  @override
  String get requireSql => 'يتطلب مستند SQL';

  @override
  String get requireSession => 'يتطلب جلسة متصلة ذات حالة معروفة';

  @override
  String get requireResult => 'يتطلب بيانات محتفظًا بها';

  @override
  String get requireObject => 'يتطلب كائنًا مستهدفًا';

  @override
  String get cancelRequested => 'طُلب الإلغاء';

  @override
  String get cancelled => 'أُلغي';

  @override
  String get queued => 'في قائمة الانتظار';

  @override
  String get running => 'قيد التشغيل';

  @override
  String get completed => 'اكتمل';

  @override
  String get failed => 'فشل';

  @override
  String get partial => 'جزئي';

  @override
  String get sessionSharing => 'مشاركة جلسة موجودة (متقدم)';

  @override
  String get production => 'إنتاج';

  @override
  String get staging => 'ما قبل الإنتاج';

  @override
  String get development => 'تطوير';

  @override
  String get executionOptions => 'إعدادات التنفيذ';

  @override
  String get resultRowLimit => 'حد صفوف النتائج (1–1000000)';

  @override
  String get boundedRead => 'قراءة محدودة';

  @override
  String get streamingRead => 'قراءة متدفقة · تمتلك معاملة قراءة';

  @override
  String get stopOnError => 'إيقاف البرنامج النصي عند الخطأ';

  @override
  String get continueOnError =>
      'متابعة عند الخطأ · ربما ثُبتت العبارات السابقة';

  @override
  String get loadMore => 'تحميل المزيد';

  @override
  String get favorite => 'تبديل المفضلة';

  @override
  String get connectionGroup => 'مجموعة اتصالات';

  @override
  String get copyRange => 'نسخ النطاق';

  @override
  String get inspectValue => 'فحص القيمة';

  @override
  String get editConnection => 'تحرير الاتصال';

  @override
  String get chooseSnapshot => 'اختيار لقطة';

  @override
  String get captureSchema => 'التقاط المخطط';

  @override
  String get sameSchemaRestriction =>
      'يجب أن تتطابق محركات قاعدة البيانات وأسماء المخططات وإصدارات اللقطات. المقارنة والحفظ لا يطبّقان تغييرات أبدًا.';

  @override
  String get restoredTaskState =>
      'استُعيد مرجع هذا المستند. أدلة الخادم والجلسات والمهام السابقة غير متاحة. اختر إجراءً صريحًا للفحص أو بدء عمل جديد؛ الاستعادة لا تتصل ولا تنفذ SQL ولا تعيد تطبيق التغييرات أبدًا.';

  @override
  String get preChangeSnapshot =>
      'لقطة قبل التغيير · ثُبتت التغييرات. حدّث صراحةً لفحص الصفوف الحالية والقيم الافتراضية للخادم.';

  @override
  String get sqlProvenance => 'مصدر SQL';

  @override
  String get assessEditing => 'تقييم قابلية التحرير';

  @override
  String get viewDetails => 'عرض التفاصيل';

  @override
  String get gridMenu => 'شبكة البيانات';

  @override
  String get visibleColumns => 'الأعمدة المرئية';

  @override
  String get hidden => 'مخفي';

  @override
  String get ascending => 'تصاعدي';

  @override
  String get descending => 'تنازلي';

  @override
  String get equals => 'يساوي';

  @override
  String get notEqual => 'لا يساوي';

  @override
  String get lessThan => 'أقل من';

  @override
  String get greaterThan => 'أكبر من';

  @override
  String get isNull => 'هو NULL';

  @override
  String get isNotNull => 'ليس NULL';

  @override
  String get exactValue => 'القيمة الدقيقة';

  @override
  String get sortTable => 'فرز بيانات الجدول';

  @override
  String get filterTable => 'تصفية بيانات الجدول';

  @override
  String get sortRetained => 'فرز اللقطة المحتفظ بها';

  @override
  String get filterRetained => 'تصفية اللقطة المحتفظ بها';

  @override
  String get applyView => 'تطبيق';

  @override
  String get rowsLabel => 'الصفوف';

  @override
  String get fetchedRows => 'الصفوف المجلبة';

  @override
  String get fixedSnapshot => 'لقطة ثابتة للصفوف المجلبة';

  @override
  String get limitReached => 'تم بلوغ الحد';

  @override
  String get retainedData => 'البيانات المحتفظ بها';

  @override
  String get applyRequiresAutoCommit =>
      'يتطلب التطبيق والتثبيت جلسة خاملة مع تفعيل التثبيت التلقائي.';

  @override
  String get connectionProfile => 'ملف تعريف الاتصال';

  @override
  String get basic => 'أساسي';

  @override
  String get advanced => 'متقدم';

  @override
  String get connectionName => 'الاسم';

  @override
  String get hostname => 'اسم المضيف (يُستخدم أيضًا للتحقق من TLS)';

  @override
  String get port => 'المنفذ';

  @override
  String get database => 'قاعدة البيانات';

  @override
  String get user => 'المستخدم';

  @override
  String get password => 'كلمة المرور';

  @override
  String get writableProfile => 'ملف تعريف قابل للكتابة';

  @override
  String get readonlyProfile => 'ملف تعريف للقراءة فقط';

  @override
  String get tlsVerify => 'TLS: التحقق من الشهادة واسم المضيف';

  @override
  String get tlsInsecure => 'TLS: غير آمن، دون تحقق';

  @override
  String get tlsDisabled => 'TLS: معطّل';

  @override
  String get testConnection => 'اختبار دون حفظ';

  @override
  String get saveProfile => 'حفظ';

  @override
  String get saveConnect => 'حفظ واتصال';

  @override
  String get sessionPassword => 'كلمة مرور لهذه الجلسة فقط';

  @override
  String get storedPassword => 'حفظ كلمة المرور في التخزين الآمن للنظام';

  @override
  String get chooseFile => 'اختيار ملف';

  @override
  String get testRunning => 'جارٍ اختبار الاتصال…';

  @override
  String get cancelTest => 'إلغاء الاختبار';

  @override
  String get idle => 'خامل';

  @override
  String get activeTransaction => 'معاملة مفتوحة';

  @override
  String get failedTransaction => 'فشلت المعاملة';

  @override
  String get inspectionContext => 'جلسة فحص';

  @override
  String get requireTableOrView => 'اختر جدولاً أو عرضاً';

  @override
  String get operationPending => 'عملية المستند تنتظر التأكيد';

  @override
  String get requirePlan => 'اختر تنفيذ Explain محفوظاً';

  @override
  String get openPlanDocument => 'فتح مستند الخطة';

  @override
  String get locks => 'الأقفال';

  @override
  String get statistics => 'الإحصاءات';

  @override
  String get queryStatistics => 'إحصاءات الاستعلامات';

  @override
  String get indexDiagnostics => 'تشخيص الفهارس';

  @override
  String get grants => 'الصلاحيات الممنوحة';

  @override
  String get sqlExecution => 'تنفيذ SQL';

  @override
  String get planReady => 'الخطة المحفوظة جاهزة؛ لم يُنفّذ SQL مجدداً';

  @override
  String get executionPlan => 'خطة التنفيذ';

  @override
  String get openOwner => 'فتح المالك';

  @override
  String get terminateActivity => 'إنهاء النشاط';

  @override
  String get close => 'إغلاق';

  @override
  String get previous => 'السابق';

  @override
  String get next => 'التالي';

  @override
  String get replaceSelection => 'استبدال التحديد';

  @override
  String get replaceAll => 'استبدال الكل';

  @override
  String get restartBackend => 'إعادة تشغيل العملية الخلفية';

  @override
  String get structuredTree => 'شجرة منظمة';

  @override
  String get rawOutput => 'المخرجات الخام';

  @override
  String get previousTextPage => 'صفحة النص السابقة';

  @override
  String get nextTextPage => 'صفحة النص التالية';

  @override
  String get filterChangedObjects => 'تصفية الكائنات المتغيرة';

  @override
  String get rebindVerifiedEdits => 'إعادة ربط التعديلات المتحقق منها';

  @override
  String get discardRecoveryRecord => 'تجاهل سجل الاسترداد';

  @override
  String get revertChange => 'التراجع عن التغيير المعلق';

  @override
  String get chooseSource => 'اختيار المصدر';

  @override
  String get chooseDestination => 'اختيار الوجهة';

  @override
  String get delimiterField => 'الفاصل (حرف واحد)';

  @override
  String get batchRowsField => 'صفوف لكل دفعة (1–1000)';

  @override
  String get rejectedLimit => 'حد الصفوف المرفوضة (1–1000)';

  @override
  String get previewSource => 'معاينة المصدر';

  @override
  String get reviewTransfer => 'مراجعة النقل';

  @override
  String get startImport => 'بدء الاستيراد';

  @override
  String get startRestore => 'بدء الاستعادة';

  @override
  String get startExport => 'بدء التصدير';

  @override
  String get requestCancel => 'طلب الإلغاء';

  @override
  String get sourceMapping => 'ربط المصدر والهدف';

  @override
  String get nativeTool => 'أداة أصلية';

  @override
  String get defaultOmit => 'حذف / القيمة الافتراضية لقاعدة البيانات';

  @override
  String get overwriteNever => 'عدم الاستبدال';

  @override
  String get overwriteExisting => 'استبدال الملف الموجود';

  @override
  String get planDetails => 'تفاصيل الخطة';

  @override
  String get planMetricsNote =>
      'تستخدم التقديرات والقياسات الفعلية أسماء حقول الخادم. القياسات المفقودة غير متاحة.';

  @override
  String get connected => 'متصل';

  @override
  String get disconnected => 'غير متصل';

  @override
  String get tables => 'الجداول';

  @override
  String get views => 'العروض';

  @override
  String get routines => 'الإجراءات';

  @override
  String get expand => 'توسيع';

  @override
  String get collapse => 'طي';

  @override
  String get databaseWorkbench => 'مساحة عمل قواعد البيانات';

  @override
  String get sidebar => 'الشريط الجانبي';

  @override
  String get unchanged => 'دون تغيير';

  @override
  String get reviewDetails => 'تفاصيل المراجعة';

  @override
  String get generatedSql => 'SQL المُولّد';

  @override
  String get changeReverted =>
      'تم التراجع عن التغيير المعلّق. اطلب مراجعة جديدة.';

  @override
  String get unknownBatch =>
      'النتيجة غير معروفة. ربما ثُبّتت الدفعة. لا تعِد تشغيلها تلقائياً؛ تحقق من الجلسة وسجل الاسترداد.';

  @override
  String get expiredChangeReview =>
      'تغيّر الهدف أو انتهت صلاحية المراجعة. اطلب مراجعة جديدة.';

  @override
  String get applyCommitExplanation =>
      'يبدأ التطبيق والتثبيت معاملة خاصة به ويثبتها. يجب أن تكون وحدة المصدر خاملة مع تفعيل التثبيت التلقائي. عالج معاملات SQL اليدوية بشكل منفصل.';

  @override
  String get newRow => 'صف جديد';

  @override
  String get original => 'الأصلي';

  @override
  String get proposed => 'المقترح';

  @override
  String changeCounts(int inserts, int updates, int deletes) {
    return '$inserts إدراج · $updates تحديث · $deletes حذف';
  }

  @override
  String sourceRow(String row) {
    return 'صف المصدر $row';
  }

  @override
  String get refreshing => 'جارٍ التحديث…';

  @override
  String get refreshActivities => 'تحديث الأنشطة';

  @override
  String get explicitRefresh => 'تحديث صريح';

  @override
  String get pollFiveSeconds => 'استعلام كل 5 ثوانٍ';

  @override
  String get cancelSelectedActivity => 'إلغاء النشاط المحدد';

  @override
  String get terminateSelectedSession => 'إنهاء الجلسة المحددة';

  @override
  String get filterActivities => 'تصفية الأنشطة الحالية';

  @override
  String get blockedBy => 'محظور بواسطة:';

  @override
  String get delete => 'حذف';

  @override
  String get remove => 'إزالة';

  @override
  String get up => 'أعلى';

  @override
  String get search => 'بحث';

  @override
  String get yes => 'نعم';

  @override
  String get no => 'لا';

  @override
  String get clear => 'مسح';

  @override
  String get copy => 'نسخ';

  @override
  String get insert => 'إدراج';

  @override
  String get update => 'تحديث';

  @override
  String get open => 'فتح';

  @override
  String get migrationEngineMismatch =>
      'يجب أن يستخدم اتصال التطبيق نفس محرك اللقطات المقارنة. لا يُدعم الترحيل بين المحركات.';

  @override
  String get metadataContextChanged =>
      'تغيّر سياق الفحص. حدّث البيانات الوصفية بشكل صريح.';

  @override
  String get newTableName => 'اسم الجدول الجديد';

  @override
  String get routineIdentity => 'هوية الروتين الدقيقة';

  @override
  String get objectColumnName => 'اسم الكائن / العمود';

  @override
  String get builtInType => 'نوع مدمج';

  @override
  String get sqlExpression => 'تعبير SQL (يُزال عند تركه فارغًا)';

  @override
  String get newPropertyValue => 'قيمة الخاصية الجديدة';

  @override
  String get columnComment => 'تعليق العمود';

  @override
  String get columnCollation => 'ترتيب العمود (الفارغ يستخدم إعداد الخادم)';

  @override
  String get addDesignedColumn => 'إضافة عمود إلى الجدول الجديد';

  @override
  String get checkExpression => 'تعبير CHECK';

  @override
  String get referencedSchema => 'المخطط / قاعدة البيانات المشار إليها';

  @override
  String get generating => 'جارٍ الإنشاء…';

  @override
  String get generateReviewedDdl => 'إنشاء DDL للمراجعة';

  @override
  String get inspectCapturedDefinition => 'فحص التعريف الملتقط';

  @override
  String get capturedObject => 'الكائن الملتقط';

  @override
  String get designReviewNote =>
      'تُنشأ التغييرات للمراجعة. تظل محتويات قاعدة البيانات دون تغيير حتى التنفيذ المُراجع.';

  @override
  String get columnMetadataUnavailable =>
      'بيانات الأعمدة الوصفية غير متاحة لهذا النطاق؛ افحص المخطط المحدد قبل تصميم قائمة أعمدة.';

  @override
  String get ordinaryColumn => 'عمود عادي';

  @override
  String get columnWithDefault => 'عمود بقيمة افتراضية';

  @override
  String get identityColumn => 'هوية / زيادة تلقائية';

  @override
  String get generatedColumn => 'عمود مُولّد';

  @override
  String get columnType => 'نوع العمود';

  @override
  String get nullableNotNull => 'يقبل NULL / NOT NULL';

  @override
  String get defaultExpression => 'تعبير افتراضي';

  @override
  String get generatedExpression => 'تعبير مُولّد';

  @override
  String get columnCollationProperty => 'ترتيب العمود';

  @override
  String get loggedUnlogged => 'مسجّل / غير مسجّل';

  @override
  String get tableComment => 'تعليق الجدول';

  @override
  String get storageEngine => 'محرك التخزين';

  @override
  String get tableCollation => 'ترتيب الجدول';

  @override
  String get rowFormat => 'تنسيق الصف';

  @override
  String get createOrReplace => 'إنشاء أو استبدال';

  @override
  String get dropSelectedObject => 'حذف الكائن المحدد';

  @override
  String get addColumn => 'إضافة عمود';

  @override
  String get editColumnProperties => 'تحرير خصائص العمود';

  @override
  String get tableProperties => 'خصائص الجدول';

  @override
  String get triggerDefinition => 'تعريف المُشغّل';

  @override
  String get createTable => 'إنشاء جدول';

  @override
  String get viewDefinition => 'تعريف العرض';

  @override
  String get routineDefinition => 'تعريف الروتين';

  @override
  String get chooseExistingObject => 'اختيار كائن موجود';

  @override
  String get nullable => 'يقبل NULL';

  @override
  String get removeIdentity => 'إزالة الهوية';

  @override
  String get generatedAlways => 'يُولّد دائمًا';

  @override
  String get generatedByDefault => 'يُولّد افتراضيًا / زيادة تلقائية';

  @override
  String get loggedTable => 'جدول مسجّل';

  @override
  String get unloggedTable => 'جدول غير مسجّل';

  @override
  String get orderedPrimaryKeyColumns => 'أعمدة المفتاح الأساسي بالترتيب';

  @override
  String get orderedColumns => 'أعمدة مرتبة';

  @override
  String get ordinaryIndex => 'فهرس عادي';

  @override
  String get uniqueIndex => 'فهرس فريد';

  @override
  String get primaryKey => 'مفتاح أساسي';

  @override
  String get uniqueConstraint => 'قيد فريد';

  @override
  String get foreignKey => 'مفتاح خارجي';

  @override
  String get checkConstraint => 'قيد CHECK';

  @override
  String get immediateChecking => 'تحقق فوري';

  @override
  String get deferrableChecking => 'تحقق قابل للتأجيل';

  @override
  String get initiallyImmediate => 'فوري مبدئيًا';

  @override
  String get initiallyDeferred => 'مؤجل مبدئيًا';

  @override
  String get referencedTable => 'الجدول المشار إليه';

  @override
  String get orderedReferencedColumns =>
      'الأعمدة المشار إليها بالترتيب المطابق';

  @override
  String get objectDefinitionEditor => 'محرر SQL لتعريف الكائن الأصلي';

  @override
  String get onDelete => 'عند الحذف';

  @override
  String get onUpdate => 'عند التحديث';

  @override
  String get stay => 'البقاء';

  @override
  String get saveSqlClose => 'حفظ SQL وإغلاق';

  @override
  String get discardSqlClose => 'تجاهل SQL وإغلاق';

  @override
  String get closeBusyData => 'إغلاق BusyData';

  @override
  String get saveDraftsClose => 'حفظ المسودات وإغلاق';

  @override
  String get closeWithoutRecovery => 'إغلاق دون استرداد';

  @override
  String get recoveryFailed => 'فشل الاسترداد';

  @override
  String get discardFailedSaveClose => 'تجاهل الحفظ الفاشل وإغلاق';

  @override
  String get closeWithoutSavingRecovery => 'إغلاق دون حفظ الاسترداد';

  @override
  String get disableSqlRecovery => 'تعطيل استرداد SQL';

  @override
  String get historyPrivacy => 'خصوصية السجل';

  @override
  String get enableSqlRetention => 'تمكين الاحتفاظ بـ SQL';

  @override
  String get disableSqlRetention => 'تعطيل الاحتفاظ بـ SQL';

  @override
  String get clearHistory => 'مسح السجل';

  @override
  String get deleteHistoryEntry => 'حذف إدخال السجل';

  @override
  String get deleteSelected => 'حذف المحدد';

  @override
  String get saveRetention => 'حفظ الاحتفاظ';

  @override
  String get retentionDays => 'أيام الاحتفاظ';

  @override
  String get sqlTextRetained => 'نص SQL محفوظ';

  @override
  String get sqlTextDisabled => 'نص SQL معطّل';

  @override
  String get openHistoryQuery => 'فتح في تبويب SQL جديد';

  @override
  String get caCertificateFile => 'ملف شهادة CA';

  @override
  String get clientCertificateFile => 'ملف شهادة العميل';

  @override
  String get clientKeyFile => 'ملف مفتاح العميل';

  @override
  String get directConnection => 'اتصال مباشر';

  @override
  String get sshTunnel => 'نفق SSH';

  @override
  String get sshHost => 'مضيف SSH';

  @override
  String get sshPort => 'منفذ SSH';

  @override
  String get sshUser => 'مستخدم SSH';

  @override
  String get reviewedKnownHosts => 'ملف known_hosts المُراجع';

  @override
  String get reviewSshKey => 'مراجعة مفتاح مضيف SSH';

  @override
  String get changedSshKey => 'تغيّر مفتاح مضيف SSH';

  @override
  String get verifyFingerprint =>
      'تحقق من هذه البصمة بشكل مستقل قبل الوثوق بها.';

  @override
  String get selectedKeyPassword => 'المفتاح أو كلمة المرور المحددة';

  @override
  String get selectedAgentIdentity => 'هوية وكيل SSH المحددة';

  @override
  String get selectedAgentSocket =>
      'مقبس وكيل Linux / قناة Windows المسماة المحددة';

  @override
  String get selectedKeyFingerprint => 'بصمة المفتاح المحدد · SHA256:…';

  @override
  String get selectedPrivateKey => 'المفتاح الخاص المحدد (اختياري)';

  @override
  String get sshPassword => 'كلمة مرور SSH';

  @override
  String get keyPassphrase => 'عبارة مرور المفتاح';

  @override
  String get connectionTimeout => 'مهلة الاتصال · 1–120 ثانية';

  @override
  String get sqlTimeout => 'مهلة تنفيذ/جلب SQL · 1–3600 ثانية (0 = 60)';

  @override
  String get schemasEquivalent => 'المخططات الملتقطة متكافئة.';

  @override
  String get migrationComplete => 'يشمل الترحيل الفروق الملتقطة المدعومة.';

  @override
  String get migrationPartial => 'ترحيل جزئي؛ تبقى فروق غير مدعومة.';

  @override
  String get differencesLimited =>
      'عرض الفروق محدود. راجع اللقطات المحفوظة الكاملة وSQL المولّد.';

  @override
  String get absent => 'غير موجود';

  @override
  String get definitionPreviewLimited =>
      'معاينة التعريف محدودة؛ استخدم اللقطة الأصلية للأدلة الكاملة.';

  @override
  String get migrationBatchNote =>
      'SQL دفعة واحدة مرتبة حسب التبعيات. اختيار كائن منفرد للفحص ولا يحدد عبارات للتطبيق.';

  @override
  String get unsupportedLabel => 'غير مدعوم';

  @override
  String get differenceAdded => 'مضاف';

  @override
  String get differenceRemoved => 'محذوف';

  @override
  String get differenceChanged => 'مغيّر';

  @override
  String get selectHistoryEntry => 'حدد إدخالًا من السجل';

  @override
  String get searchSqlTarget => 'بحث SQL أو الهدف';

  @override
  String get closeSqlTab => 'إغلاق تبويب SQL';

  @override
  String get historyMetadataRetained => 'تبقى بيانات الحالة والهدف في السجل.';

  @override
  String get historyPreviewNote =>
      'معاينة فقط. افتح في تبويب SQL جديد لاسترجاع النص المحفوظ.';

  @override
  String get selected => 'محدد';

  @override
  String get authReviewNote =>
      'راجع هوية المستخدم أو الدور والهدف بدقة قبل التطبيق. لا تُوضع بيانات الاعتماد في مستندات SQL أو السجل أبدًا. تبقى الاتصالات الحالية وكلمات المرور المحفوظة منفصلة.';

  @override
  String get createLogin => 'إنشاء حساب دخول';

  @override
  String get createRole => 'إنشاء دور دون دخول';

  @override
  String get setPassword => 'تعيين كلمة مرور';

  @override
  String get preventLogin => 'منع عمليات دخول جديدة';

  @override
  String get allowLogin => 'السماح بعمليات دخول جديدة';

  @override
  String get dropPrincipal => 'حذف المستخدم أو الدور';

  @override
  String get principalName => 'الاسم الدقيق للمستخدم أو الدور';

  @override
  String get accountHost => 'مضيف الحساب الدقيق (البدائل توسّع نطاق الدخول)';

  @override
  String get newPassword => 'كلمة مرور جديدة';

  @override
  String get repeatPassword => 'كرر كلمة المرور الجديدة';

  @override
  String get reviewAccount => 'مراجعة عملية الحساب';

  @override
  String get passwordsMismatch => 'أدخل كلمة المرور نفسها غير الفارغة مرتين';

  @override
  String get accountSubmitFailed =>
      'تعذر إرسال عملية الحساب. تحقق من الهدف وسياسة المصادقة وصلاحيات قاعدة البيانات.';

  @override
  String get privilegeReviewNote =>
      'افحص الصلاحيات المباشرة؛ لا يزال SQL المُولّد يتطلب مراجعة التنفيذ.';

  @override
  String get inspectionLimited =>
      'الحد 500 صف لكل قسم. ضيّق البحث؛ القسم الفارغ لا يثبت غياب الوصول الفعلي.';

  @override
  String get findPrincipal => 'ابحث عن اسم مستخدم / دور';

  @override
  String get searchPrincipals => 'البحث عن المستخدمين والأدوار';

  @override
  String get choosePrincipal => 'اختر مستخدمًا أو دورًا';

  @override
  String get inspectGrants => 'افحص الصلاحيات المحددة';

  @override
  String get tablePrivileges => 'صلاحيات الجدول / العرض';

  @override
  String get schemaPrivileges => 'صلاحيات المخطط';

  @override
  String get databasePrivileges => 'صلاحيات قاعدة البيانات';

  @override
  String get roleMembership => 'عضوية الدور';

  @override
  String get defaultRole => 'تفعيل الدور الافتراضي';

  @override
  String get chooseGrantRole => 'اختر الدور لمنحه / سحبه';

  @override
  String get tableView => 'جدول / عرض';

  @override
  String get explicitPrivileges => 'صلاحيات صريحة (مفصولة بفواصل)';

  @override
  String get setDefaultRole => 'تعيين الدور الافتراضي المحدد';

  @override
  String get clearDefaultRole => 'مسح الدور الافتراضي';

  @override
  String get grantAccess => 'منح الوصول';

  @override
  String get revokeAccess => 'سحب الوصول';

  @override
  String get withoutDelegation => 'دون تفويض';

  @override
  String get allowDelegation => 'السماح للمستلم بمنح الآخرين';

  @override
  String get readonlyChanges =>
      'هذا الملف للقراءة فقط. تتطلب التغييرات جلسة تسمح بالكتابة صراحةً.';

  @override
  String get createPrincipal => 'إنشاء مستخدم / دور';

  @override
  String get manageAuthentication => 'إدارة المصادقة المحددة';

  @override
  String get openPrivilegeSql => 'فتح SQL الصلاحيات للمراجعة';

  @override
  String get inspectPrincipalFirst =>
      'افحص المستخدم أو الدور المحدد قبل إعداد تغيير';

  @override
  String get accountAuthentication => 'مصادقة الحساب';

  @override
  String get schema => 'المخطط';

  @override
  String get available => 'متاح';

  @override
  String get availableEmpty => 'متاح · بيانات فارغة';

  @override
  String get limitedVisibility => 'رؤية أو نطاق محدود';

  @override
  String get permissionDenied => 'الإذن مرفوض';

  @override
  String get unavailable => 'غير متاح';

  @override
  String get profileDisabled => 'معطّل بواسطة الملف';

  @override
  String get unknownState => 'غير معروف';

  @override
  String get inspecting => 'جارٍ الفحص…';

  @override
  String get refreshCapabilities => 'تحديث الإمكانات';

  @override
  String get staleRefresh => 'قديم · حدّث بعد الاتصال';

  @override
  String get staleContext => 'قديم · حدّث بعد الاتصال أو تغيير السياق';

  @override
  String get partialTreeLimit =>
      'جزئي · بلغ حد الشجرة؛ ضيّق البحث عن كائنات قاعدة البيانات';

  @override
  String get schemaComparison => 'مقارنة المخططات';

  @override
  String get searchTable => 'البحث عن جدول';

  @override
  String get focusObject => 'تركيز';

  @override
  String get exportSvg => 'تصدير SVG';

  @override
  String get exportPng => 'تصدير PNG';

  @override
  String get diagramNotes => 'ملاحظات المخطط (مضمّنة في SVG)';

  @override
  String get openNotes => 'فتح الملاحظات';

  @override
  String get saveNotes => 'حفظ الملاحظات';

  @override
  String get newSnippet => 'مقتطف جديد';

  @override
  String get snippetName => 'اسم المقتطف';

  @override
  String get saveSnippet => 'حفظ المقتطف';

  @override
  String get deleteSnippet => 'حذف المقتطف المحفوظ';

  @override
  String get insertSnippet => 'إدراج في مستند SQL';

  @override
  String get snippetEditor => 'محرر مقتطف SQL';

  @override
  String get snippetsNote =>
      'أدرج SQL المحلي المحفوظ في المستند المحدد مع التراجع. يبقى التنفيذ صريحًا.';

  @override
  String get level => 'المستوى';

  @override
  String get expanded => 'موسّع';

  @override
  String get collapsed => 'مطوي';

  @override
  String get treeLevel => 'المستوى';

  @override
  String get retainedView => 'عرض محفوظ';

  @override
  String get tableQuerySnapshot => 'لقطة استعلام الجدول';

  @override
  String get originalResultNote =>
      'النتيجة الأصلية المحفوظة؛ التصفح والفحص لا ينفّذان SQL';

  @override
  String get tableFilterNote =>
      'يرسل التطبيق استعلام قاعدة بيانات جديدًا تمت مراجعته. تبقى اللقطة السابقة متاحة.';

  @override
  String get retainedFilterNote =>
      'كل الصفوف المجلوبة في لقطة ثابتة. لا يُعاد تنفيذ SQL. قد يختلف الترتيب المحفوظ عن ترتيب قاعدة البيانات.';

  @override
  String get retainedRowNote =>
      'اختر صفًا ضمن النتيجة المجلوبة بالفعل. لا يُعاد تنفيذ SQL.';

  @override
  String get copyLimitNote =>
      'النسخ محدود بـ 10,000 خلية؛ صدّر البيانات المحفوظة للنطاقات الأكبر.';

  @override
  String get inlineValueLimit => 'التحرير داخل الخلية يدعم قيمًا حتى 8KiB';

  @override
  String get editContextChanged =>
      'تغيّرت جلسة المصدر أو سياق قابلية التحرير؛ افحص التقييم أو حدّثه قبل تجهيز التغييرات';

  @override
  String get editAssessmentUnavailable =>
      'قابلية التحرير غير متاحة؛ حدّث التقييم عندما تكون الجلسة خاملة';

  @override
  String get rowChangeReverted =>
      'تم التراجع عن تغيير الصف المعلّق؛ قاعدة البيانات لم تتغيّر';

  @override
  String get sqlCopyRequiresMetadata =>
      'نسخ SQL يتطلب العملية الخلفية وبيانات الأنواع المحفوظة.';

  @override
  String get exportFullValue => 'تصدير القيمة المحفوظة كاملة';

  @override
  String valueExportReview(String bytes, String path) {
    return 'حفظ $bytes بايت إلى $path؟ سيُستبدل المحتوى الموجود. لا يُعاد تنفيذ SQL.';
  }

  @override
  String get goToRetainedRow => 'الانتقال إلى صف محفوظ';

  @override
  String get row => 'الصف';

  @override
  String get go => 'انتقل';

  @override
  String get retryRows => 'إعادة محاولة الصفوف المحفوظة';

  @override
  String get previousRows => 'الصفوف السابقة';

  @override
  String get nextRows => 'الصفوف التالية';

  @override
  String get firstWindow => 'أول نافذة محفوظة';

  @override
  String get lastWindow => 'آخر نافذة مجلوبة';

  @override
  String get setNull => 'تعيين NULL';

  @override
  String copyFormat(String format) {
    return 'نسخ $format';
  }

  @override
  String get textValue => 'نص';

  @override
  String get sqlValues => 'قيم SQL';

  @override
  String get rowSelection => 'تحديد الصفوف';

  @override
  String selectRow(String row) {
    return 'تحديد الصف $row';
  }

  @override
  String columnHeader(String column) {
    return 'العمود $column';
  }

  @override
  String get pendingChange => 'تغيير معلّق';

  @override
  String get readonlyCell => 'خلية للقراءة فقط';

  @override
  String get editableCell => 'خلية قابلة للتحرير';

  @override
  String get loadValueFirst => 'حمّل هذه القيمة المحفوظة أولًا';

  @override
  String get editUnavailable => 'قابلية التحرير غير متاحة';

  @override
  String get editCell => 'تحرير الخلية';

  @override
  String get unsupportedEditValue => 'هذه القيمة المحفوظة تدعم الفحص فقط';

  @override
  String bytesCount(String bytes) {
    return '$bytes بايت';
  }

  @override
  String get problems => 'المشكلات';

  @override
  String get ownedSessions => 'الجلسات المملوكة';

  @override
  String get noProblems => 'لا توجد مشكلات مسجّلة';

  @override
  String get duplicateConnection => 'تكرار الاتصال';

  @override
  String get deleteConnection => 'حذف الاتصال';

  @override
  String deleteConnectionReview(String name) {
    return 'حذف $name؟ تحتفظ الجلسات الفعلية الحالية بإعداداتها الأصلية.';
  }

  @override
  String get unresolvedSessions => 'الجلسات غير المحسومة';

  @override
  String get disconnectSessionNote =>
      'عالج المهام والمعاملات النشطة أولاً. يؤثر قطع الاتصال على جميع مستخدمي هذه الجلسة الفعلية؛ ولا ينفّذ التزاماً أو يعيد SQL. تبقى النتائج غير المعروفة غير معروفة.';

  @override
  String get transferSettingsChanged => 'تغيرت إعدادات النقل؛ راجع مجدداً';

  @override
  String get transferReviewReady =>
      'المراجعة جاهزة؛ تحقق من الهدف والنطاق والتعيين والملف قبل البدء';

  @override
  String get sourcePreviewNotice => 'معاينة المصدر؛ لم تُستورد صفوف';

  @override
  String get transferRequiresReview => 'راجع عملية النقل هذه أولاً';

  @override
  String get transferSubmittedNotice =>
      'تم الإرسال؛ الإلغاء لا يتراجع عن التزامات أو ملفات مؤكدة';

  @override
  String get sqlExportExecutionNote => 'تنفيذ SQL جديد خضع للمراجعة';

  @override
  String get retainedExportSnapshotNote =>
      'لقطة الصفوف المجلوبة؛ لا يُنفّذ SQL';

  @override
  String get restorePartialCommitNote =>
      'قد تُثبت الاستعادة أجزاءً. الإلغاء لا يتراجع عن الاستعادة.';

  @override
  String get sourcePreviewLimit => 'معاينة المصدر؛ حتى 20 صفاً';

  @override
  String get importBatchSafetyNote =>
      'الأخطاء والإلغاء يبقيان التزامات الدفعات السابقة. تُراجع بصمات المصدر والمواد الثابتة قبل الإرسال.';

  @override
  String get nullMarkerLiteralNote =>
      'علامة NULL غير مقتبسة؛ العلامة المقتبسة نص حرفي';

  @override
  String immutableSourceHash(String hash) {
    return 'SHA-256 للمصدر الثابت: $hash';
  }

  @override
  String sourceColumnLabel(String column) {
    return 'عمود المصدر $column';
  }

  @override
  String previewRowLabel(String row, String column, String value) {
    return 'صف المعاينة $row، $column: $value';
  }

  @override
  String get transferCancellationNotice => 'طُلب الإلغاء؛ انتظر التأكيد';

  @override
  String transferProgress(String processed, String committed, String rejected) {
    return '$processed معالَج · $committed مُثبت · $rejected مرفوض';
  }

  @override
  String get importAtomicPolicy => 'كل الصفوف في معاملة واحدة';

  @override
  String get importBatchPolicy => 'تثبيت الدفعات؛ التوقف عند الخطأ';

  @override
  String get importSkipPolicy => 'تجاوز الصفوف غير الصالحة؛ تثبيت الدفعات';

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
    return 'تأكيدات/اتصالات: $operations\nمستندات غير محفوظة: $documents\nحفظ جارٍ: $saves\nتعديلات معلقة: $edits\nمهام نشطة: $jobs\nمعاملات تحتاج تنظيفاً: $transactions\nنتائج عمليات غير معروفة: $unknown\nجلسات غير مؤكدة: $sessions';
  }

  @override
  String get closeDraftSaved => 'ستُحفظ مسودات SQL محلياً.';

  @override
  String get closeDraftLost =>
      'الاسترداد معطّل؛ ستُفقد SQL وتصاميم الكائنات غير المحفوظة.';

  @override
  String get closeDesignRecovery =>
      'تصاميم الكائنات تستخدم استرداداً خاصاً محدوداً. أعد الاتصال وافحص البيانات الوصفية صراحةً بعد الفتح.';

  @override
  String get closeCleanupReview =>
      'إغلاق آخر مالك للجلسة يطلب الإلغاء ويتراجع عن المعاملات المؤكدة ويقطع الاتصال. تبقى النتائج المجهولة مجهولة؛ لا يُثبت SQL ولا يُعاد تنفيذه.';

  @override
  String get closeSharedSession =>
      'يحتفظ المستخدمون الآخرون بجلستهم الفعلية المشتركة.';

  @override
  String get closeStagedRecovery =>
      'التغييرات المعلقة تحتاج استرداداً خاصاً مؤكداً وإعادة اتصال ومراجعة جديدة.';

  @override
  String get closeRecoveryLoss =>
      'تعذر حفظ المستندات والتخطيط. قد يفقد الإغلاق SQL والتغييرات غير المحفوظة؛ تبقى الملفات وبيانات الاسترداد السابقة.';

  @override
  String get closeWaitNotice =>
      'انتظر تأكيدات العمليات وتنظيف الاتصالات قبل الإغلاق.';

  @override
  String get saveFailedNotice =>
      'فشل حفظ SQL. احتفظ بالنص المعدل أو تجاهله صراحةً.';

  @override
  String get closeCleanupFailed => 'فشل تنظيف الخادم؛ يبقى BusyData مفتوحاً.';

  @override
  String get closeBackendUnverified =>
      'حالة الخادم غير مؤكدة؛ قد تبقى عمليات معلقة.';

  @override
  String historyRetainSqlReview(String days) {
    return 'قد يحتوي SQL أسراراً. حفظ النص لمدة $days يوماً؟';
  }

  @override
  String get historyStopSqlReview => 'إيقاف تخزين SQL وحذفه من السجل السابق؟';

  @override
  String get historyClearReview =>
      'حذف السجل كله؟ قد تسجل العمليات النشطة نتيجتها عند الانتهاء.';

  @override
  String get historyDeleteReview => 'حذف إدخال السجل المحدد؟';

  @override
  String get historyRetentionRange => 'الاحتفاظ يجب أن يكون 1–3650 يوماً';

  @override
  String get enableSqlHistory => 'تفعيل سجل SQL';

  @override
  String get stopSqlHistory => 'إيقاف الاحتفاظ بـ SQL';

  @override
  String get recoveryDiscardReview =>
      'تجاهل سجل الاسترداد؟ تحقق من النتائج المجهولة أولاً؛ التجاهل لا يتراجع عن التغييرات المثبتة.';

  @override
  String closeSqlSummary(String unsaved, String edits, String jobs) {
    return 'SQL غير محفوظ: $unsaved\nتغييرات معلقة: $edits\nمهام نشطة: $jobs';
  }

  @override
  String get recoveryStayOpen =>
      'فشل الاسترداد. يبقى BusyData مفتوحاً؛ العمل غير المحفوظ محفوظ في الذاكرة.';

  @override
  String get commitUncertaintyNote =>
      'قد يجعل فشل الشبكة نتيجة الالتزام غير معروفة. لا تُعِد المحاولة تلقائياً.';

  @override
  String get closeObjectDesignDiscard =>
      'ستُتجاهل حقول تصميم الكائن غير المحفوظة. ولّد SQL واحفظه أولاً للاحتفاظ بالتصميم.';

  @override
  String get savePrivateDrafts => 'حفظ مسودات استرداد خاصة';

  @override
  String get noPrivateDrafts => 'عدم حفظ مسودات الاسترداد';

  @override
  String shortcutField(String command) {
    return 'اختصار $command';
  }

  @override
  String get shortcutInvalid =>
      'استخدم اختصارًا صالحًا غير مخصص لإجراء آخر. F6 وShift+F6 محجوزان.';

  @override
  String get disableRecoveryReview =>
      'حذف استرداد SQL والتصاميم والتغييرات المحلية؟ يبقى العمل غير المحفوظ مفتوحاً؛ قد يضيع بانهيار. تحقق من النتائج المجهولة أولاً.';

  @override
  String get preferencesSaved => 'حُفظت الإعدادات';

  @override
  String get sharingSessionReview =>
      'يشارك هذا الاستعلام الجلسة الفعلية المسماة والمعاملة والكائنات المؤقتة والإعدادات مع المستخدمين المذكورين. إغلاق مستخدم يبقي الآخرين.';

  @override
  String get recoveryReconcileFirst =>
      'عالج التغييرات الجارية أو المجهولة قبل تعطيل الاسترداد. تجاهل سجلات الاسترداد عبر مراجعتها الصريحة فقط.';

  @override
  String get enterSearchText => 'أدخل نص البحث';

  @override
  String get noSearchMatches => 'لا توجد نتائج';

  @override
  String searchMatchCount(String position, String total) {
    return 'النتيجة $position من $total';
  }

  @override
  String get formatSqlChanged =>
      'تغير SQL أو الهدف. حُفظ النص الأصلي؛ اطلب معاينة تنسيق جديدة.';

  @override
  String get formatSqlUnavailable =>
      'التنسيق غير متاح لصياغة ناقصة أو غير مدعومة أو حدود التحليل. حُفظ SQL الأصلي.';

  @override
  String get stageChange => 'تجهيز التغيير';

  @override
  String pendingChangesCount(String count) {
    return '$count تغييرات معلقة؛ قاعدة البيانات دون تغيير حتى التطبيق المراجع.';
  }

  @override
  String discardChangesCount(String count) {
    return 'تجاهل $count تغييرات معلقة؟ لا تُرسل عملية لقاعدة البيانات.';
  }

  @override
  String get recoveryNoExecution =>
      'الاسترداد لا يتصل ولا ينفذ SQL المصدر ولا يستأنف المعاملات أو يعيد التغييرات. لا يمكن إعادة السجلات المجهولة أو الملتزمة.';

  @override
  String get recoveredDesign =>
      'تصميم مسترد. اتصل صراحة وافحص البيانات الحالية قبل مراجعة جديدة. لم يجلب الاسترداد SQL أو بيانات وصفية.';

  @override
  String get retainedUnavailable =>
      'البيانات المحتفظ بها غير متاحة. يبقى SQL المحفوظ والاسترداد الخاص محلياً.';

  @override
  String get activityFingerprintNote =>
      'تُراجع بصمة النشاط المحدد قبل الإرسال. قد تكون نتائج الكتابة مجهولة.';

  @override
  String replaceFileReview(String path) {
    return 'استبدال الملف المراجع في $path؟ يتطلب تغير الوجهة مراجعة جديدة.';
  }

  @override
  String get diagramPngSaved =>
      'حُفظ مخطط PNG. تظهر الملاحظات الطويلة حتى ستة أسطر.';

  @override
  String get editTargetChanged =>
      'تغير هدف التحرير. أعد فتح محرر الصف قبل التجهيز.';

  @override
  String affectedRowCount(String count) {
    return 'الصفوف المتأثرة: $count';
  }

  @override
  String get zoomIn => 'تكبير';

  @override
  String get zoomOut => 'تصغير';

  @override
  String get resetView => 'إعادة ضبط العرض';

  @override
  String get diagramKeys =>
      'الأسهم للتحريك؛ + و - للتكبير والتصغير؛ Home لإعادة ضبط العرض.';

  @override
  String get explorerConnected => 'المستكشف متصل';

  @override
  String get explorerDisconnected => 'المستكشف غير متصل';

  @override
  String querySessionCount(String count) {
    return 'جلسات الاستعلام $count';
  }

  @override
  String get metadataColumn => 'العمود';

  @override
  String get metadataPosition => 'الموضع';

  @override
  String get metadataUnique => 'فريد';

  @override
  String get metadataJdbcType => 'نوع JDBC';

  @override
  String get metadataAutoIncrement => 'زيادة تلقائية';

  @override
  String get metadataReferencedColumn => 'العمود المشار إليه';

  @override
  String get metadataComment => 'تعليق';

  @override
  String get metadataType => 'النوع';

  @override
  String get metadataEvent => 'الحدث';

  @override
  String get metadataSpecificName => 'المعرّف الأصلي المحدد';

  @override
  String get metadataOptions => 'الخيارات';

  @override
  String get metadataInheritance => 'الوراثة';

  @override
  String get metadataDefinitionCaptured => 'التعريف الأصلي الملتقط';

  @override
  String get metadataDefinitionUnavailable =>
      'التعريف غير متاح في البيانات الوصفية الملتقطة';

  @override
  String get metadataDefinitionUnsupported =>
      'الكائن الملتقط ليس له تعريف أصلي مدعوم';

  @override
  String get connections => 'الاتصالات';

  @override
  String get noConnections => 'لا توجد اتصالات بعد';

  @override
  String get startTitle => 'الاتصال بقاعدة بيانات';

  @override
  String get startDescription =>
      'اتصل بـ PostgreSQL أو MySQL أو MariaDB لتصفح الكائنات وإدارة البيانات وتشغيل الاستعلامات.';

  @override
  String get savedStartTitle => 'اختر اتصالاً';

  @override
  String get savedStartDescription =>
      'اتصل باتصال محفوظ في مستكشف قاعدة البيانات لتصفح الكائنات وتشغيل الاستعلامات.';

  @override
  String get noConnection => 'لا يوجد اتصال';

  @override
  String queryTitle(int number) {
    return 'استعلام $number';
  }

  @override
  String get sessionMenu => 'الجلسة';

  @override
  String get noFilterMatches => 'لا توجد اتصالات أو كائنات محملة مطابقة';

  @override
  String get activityState => 'الحالة';

  @override
  String get activityWait => 'الانتظار';

  @override
  String get generalSettings => 'عام';

  @override
  String get optionsSettings => 'الخيارات';

  @override
  String get host => 'المضيف';

  @override
  String get databaseSystem => 'نظام قاعدة البيانات';

  @override
  String get passwordStorage => 'تخزين كلمة المرور';

  @override
  String get environmentLabel => 'البيئة';

  @override
  String get readOnlySettings => 'سياسة القراءة فقط';

  @override
  String get tlsPolicy => 'سياسة TLS';

  @override
  String get sshConnection => 'اتصال SSH';

  @override
  String get sshAuthentication => 'مصادقة SSH';

  @override
  String get connectionTestAction => 'اختبار الاتصال';

  @override
  String get details => 'التفاصيل';

  @override
  String get copyDetails => 'نسخ التفاصيل';

  @override
  String get retry => 'إعادة المحاولة';

  @override
  String get filterCellValue => 'التصفية بهذه القيمة';

  @override
  String get connectsWhenRun => 'يتصل عند التنفيذ';

  @override
  String get connectionSaving => 'جارٍ الحفظ…';

  @override
  String get connectionConnecting => 'جارٍ الاتصال…';

  @override
  String get connectionCancelling => 'جارٍ الإلغاء…';

  @override
  String get connectionSettingsChanged =>
      'تغيّرت الإعدادات. اختبر هذه النسخة للتحقق من الاتصال.';

  @override
  String get connectionTestChanged =>
      'تغيّرت الإعدادات أثناء الاختبار. اختبر هذه النسخة مرة أخرى.';

  @override
  String get connectionRequired => 'مطلوب';

  @override
  String get connectionCorrectFields => 'صحّح الحقول المشار إليها.';

  @override
  String get connectionHostname => 'أدخل اسم مضيف أو عنوان IP';

  @override
  String get connectionSshHostname => 'أدخل اسم مضيف SSH أو عنوان IP';

  @override
  String get connectionMaxLength => 'استخدم 256 حرفًا على الأكثر';

  @override
  String get connectionTlsHelp =>
      'يجب التحقق من الشهادة والمضيف. حدد شهادة CA في SSH/SSL عند الحاجة.';

  @override
  String get connectionTlsReview => 'راجع سياسة TLS المحددة قبل الاتصال.';

  @override
  String get connectionStorageUnavailable =>
      'التخزين الآمن غير متاح. أدخل كلمة مرور واختر تخزينها للجلسة فقط صراحةً للحفظ دون التخزين الآمن.';

  @override
  String get connectionHostReviewed =>
      'تم تحديد هوية مضيف مراجَعة لهذا الملف ونقطة الاتصال.';

  @override
  String get connectionSshReviewing => 'جارٍ مراجعة مضيف SSH…';

  @override
  String get connectionFailureAuthentication =>
      'رُفضت مصادقة قاعدة البيانات. تحقق من المستخدم وكلمة المرور في عام.';

  @override
  String get connectionFailureTls =>
      'فشل التحقق من TLS. تحقق من اسم المضيف والشهادات في SSH/SSL.';

  @override
  String get connectionFailureSshKey =>
      'رُفض مفتاح مضيف SSH. راجع هوية المضيف المحددة في SSH/SSL.';

  @override
  String get connectionFailureEndpoint =>
      'تعذر الوصول إلى نقطة الاتصال. تحقق من المضيف والمنفذ وSSH/SSL.';

  @override
  String get connectionFailureCancelled =>
      'أُلغي الاتصال. تم الاحتفاظ بالقيم المدخلة.';

  @override
  String get connectionFailureSettings =>
      'رُفضت إعدادات الاتصال. راجع الحقول المسماة.';

  @override
  String get connectionFailureAccess =>
      'رفض الخادم الوصول. تحقق من بيانات الاعتماد والأذونات.';

  @override
  String get connectionFailureUnavailable =>
      'الاتصال غير متاح. تحقق من نقطة الاتصال وإعدادات TLS وSSH.';

  @override
  String get connectionFailureTimeout =>
      'انتهت مهلة الاتصال. تحقق من نقطة الاتصال ومهلة الاتصال.';

  @override
  String get connectionFailureUnknown =>
      'لم يكتمل الاتصال. راجع نقطة الاتصال وبيانات الاعتماد وإعدادات SSH/SSL.';

  @override
  String connectionNumber(int min, int max) {
    return 'أدخل عددًا صحيحًا من $min إلى $max';
  }

  @override
  String connectionSavedFailure(String name) {
    return 'تم حفظ الاتصال: $name. فشلت محاولة الاتصال. ';
  }

  @override
  String get backendBusy =>
      'الخادم مشغول. انتظر الطلب الحالي، ثم حاول مرة أخرى.';

  @override
  String rpcRequestUnconfirmed(String code) {
    return 'لم يتم تأكيد الطلب (RPC $code).';
  }

  @override
  String get operationUnconfirmed => 'تعذر إكمال العملية.';

  @override
  String get connectionFailureTlsMaterial =>
      'مواد TLS غير متاحة أو غير صالحة. تحقق من مصادر الثقة ومفتاح العميل في SSH/SSL.';

  @override
  String get managerTitle => 'مصادر البيانات وبرامج التشغيل';

  @override
  String get sourceListTitle => 'مصادر البيانات';

  @override
  String get driverLabel => 'برنامج التشغيل';

  @override
  String get connectionTypeLabel => 'نوع الاتصال';

  @override
  String get defaultTcp => 'الافتراضي (TCP)';

  @override
  String get authenticationLabel => 'المصادقة';

  @override
  String get userPasswordAuth => 'المستخدم وكلمة المرور';

  @override
  String get neverStorage => 'أبداً';

  @override
  String get initialDatabaseLabel => 'قاعدة البيانات الأولية';

  @override
  String get useSshTunnel => 'استخدام نفق SSH';

  @override
  String get sshConfigurationLabel => 'إعدادات SSH';

  @override
  String get createSshConfig => '<إنشاء إعدادات>';

  @override
  String get copySshSettings => 'نسخ إعدادات SSH';

  @override
  String get localPortLabel => 'المنفذ المحلي';

  @override
  String get dynamicPortLabel => '<ديناميكي>';

  @override
  String get useSsl => 'استخدام SSL';

  @override
  String get useTruststore => 'استخدام مخزن الثقة';

  @override
  String get clientKeyPasswordLabel => 'كلمة مرور مفتاح العميل';

  @override
  String get modeLabel => 'الوضع';

  @override
  String get requireTls => 'مطلوب';

  @override
  String get verifyCa => 'التحقق من CA';

  @override
  String get fullVerification => 'التحقق الكامل';

  @override
  String get connectionSection => 'الاتصال';

  @override
  String get configurationApplied => 'تم تطبيق الإعدادات';

  @override
  String get noOtherSshConfig => 'لا يحتوي مصدر آخر على إعدادات SSH.';

  @override
  String get generatedUrlHelp => 'عنوان JDBC مُنشأ وللقراءة فقط.';

  @override
  String get tlsDriverDefaultHelp =>
      'لم يتم إعداد SSL؛ يستخدم برنامج التشغيل المضمّن الإعداد الافتراضي.';

  @override
  String get tlsClientKeyHelp =>
      'مفاتيح PEM: ‏PKCS#8 أو OpenSSL؛ مشفرة أو غير مشفرة.';

  @override
  String get legacyMariaTrustHelp =>
      'يُحتفظ بالتحقق الحالي لبرنامج التشغيل. اختر مصادر الثقة لإعداد جذور صريحة.';

  @override
  String get metadataStartValue => 'القيمة الابتدائية';

  @override
  String get metadataMinimumValue => 'القيمة الدنيا';

  @override
  String get metadataMaximumValue => 'القيمة القصوى';

  @override
  String get metadataIncrement => 'الزيادة';

  @override
  String get metadataCycle => 'دورية';

  @override
  String get metadataCacheSize => 'حجم التخزين المؤقت';

  @override
  String get metadataLastValue => 'آخر قيمة';

  @override
  String get sequences => 'التسلسلات';

  @override
  String get namespaceSelection => 'اختيار مساحات الأسماء';

  @override
  String get namespaceSelectionNotice =>
      'يتحكم الاختيار في استكشاف البنية. تحتفظ وحدات الاستعلام بسياق تنفيذها.';

  @override
  String get allNamespaces => 'كل مساحات الأسماء';

  @override
  String get defaultNamespace => 'الافتراضي';

  @override
  String get namespacePattern => 'نمط الاسم (تعبير نمطي)';

  @override
  String namespaceCount(int selected, int known) {
    return '$selected من $known';
  }

  @override
  String get previousPage => 'الصفحة السابقة';

  @override
  String get patternRejected =>
      'النمط غير صالح أو يتجاوز حد العمل. تم الاحتفاظ بالاختيار السابق.';

  @override
  String get namespaceNotSelected => 'مساحة الأسماء غير محددة لاستكشاف البنية';

  @override
  String get newMenu => 'جديد';

  @override
  String get queryConsoles => 'وحدات الاستعلام';

  @override
  String get viewOptions => 'خيارات العرض';

  @override
  String get quickDocumentation => 'توثيق سريع';

  @override
  String get showEmptyGroups => 'إظهار المجموعات الفارغة';

  @override
  String get speedSearch => 'البحث السريع';

  @override
  String get speedSearchScope => 'العقد الموسعة والمحملة فقط.';

  @override
  String get newSourceFolder => 'مجلد مصادر جديد';

  @override
  String get renameSourceFolder => 'إعادة تسمية المجلد';

  @override
  String get moveToFolder => 'نقل إلى مجلد';

  @override
  String get moveUp => 'نقل لأعلى';

  @override
  String get moveDown => 'نقل لأسفل';

  @override
  String get folderMustBeEmpty =>
      'انقل المصادر والمجلدات الموجودة قبل إزالة هذا المجلد.';

  @override
  String get newVirtualView => 'عرض افتراضي جديد';

  @override
  String get editVirtualDefinition => 'تحرير التعريف المحلي';

  @override
  String get unboundVirtualView => 'عروض افتراضية غير مرتبطة';

  @override
  String get localVirtualViewNotice =>
      'تعريف SQL محلي. الحفظ لا ينفذ SQL ولا ينشئ عرضًا على الخادم. التشغيل يستخدم مراجعة SQL المعتادة ووحدة تحكم مستقلة.';

  @override
  String get rebindVirtualView => 'ربط التعريف المحلي هنا';

  @override
  String get sourceFolderName => 'اسم المجلد';

  @override
  String get sourceFolderPathNotice => 'استخدم / لإنشاء مجلدات متداخلة.';

  @override
  String get topLevel => 'المستوى الأعلى';

  @override
  String get virtualViewName => 'اسم العرض الافتراضي';

  @override
  String get virtualViewSql => 'تعريف SQL للعرض الافتراضي';

  @override
  String get virtualViews => 'العروض الافتراضية';

  @override
  String get revealInExplorer => 'إظهار في مستكشف قواعد البيانات';

  @override
  String get objectNotFound =>
      'لم يوجد الكائن في مساحة الأسماء هذه. حدّث البيانات الوصفية أو تحقق من الأذونات.';

  @override
  String get objectHiddenByFilter => 'الكائن مخفي بمرشح العرض الحالي.';

  @override
  String get revealFilterNotice =>
      'بحث الكائن يضيّق هذه الصفحة؛ يُحذف العدد الإجمالي للفئة.';

  @override
  String get clearObjectFilter => 'مسح بحث الكائن';

  @override
  String get compareStructure => 'مقارنة البنية';

  @override
  String get selectTwoCompatibleObjects =>
      'حدد جدولين متوافقين باستخدام Ctrl مع النقر.';

  @override
  String get scopedComparisonRestriction =>
      'تتطلب المقارنة جدولين عاديين بنفس الاسم الأصلي والمخطط والمحرك. الأنواع الأخرى ومطابقة إعادة التسمية غير متاحة.';

  @override
  String get groupNamespaces => 'تجميع قواعد البيانات والمخططات';

  @override
  String get groupSchemaObjects => 'تجميع كائنات المخطط';

  @override
  String get groupTableElements => 'تجميع عناصر الجدول';

  @override
  String get sortAlphabetically => 'ترتيب أبجدي';

  @override
  String get showVirtualObjects => 'إظهار الكائنات الافتراضية';

  @override
  String get showObjectComments => 'إظهار تعليقات الكائنات';

  @override
  String get objectTypeFilter => 'مرشح نوع الكائن';

  @override
  String get partitionedTable => 'جدول مقسّم';

  @override
  String get foreignTable => 'جدول خارجي';

  @override
  String get materializedView => 'عرض مادي';

  @override
  String get functionObject => 'دالة';

  @override
  String get procedureObject => 'إجراء';

  @override
  String get sqlSymbolUnavailable =>
      'تعذر تحديد كائن دائم بأمان عند المؤشر. اتصل بوحدة التحكم هذه واستخدم مرجع جدول أو عرض خارج القيم الحرفية والتعليقات.';

  @override
  String get sqlSymbolAmbiguous =>
      'مرجع كائن SQL ملتبس. حدد مساحة الأسماء أو اختر كائن قاعدة البيانات الدقيق.';

  @override
  String get deactivateSource => 'تعطيل المصدر';

  @override
  String get functions => 'الدوال';

  @override
  String get procedures => 'الإجراءات';

  @override
  String get separateProceduresFunctions => 'فصل الإجراءات والدوال';

  @override
  String get renameVirtualView => 'إعادة تسمية العرض الافتراضي';

  @override
  String get metadataPersistentScope =>
      'الكائنات الدائمة فقط؛ تبقى الكائنات المؤقتة والمحلية للجلسة في تنقل وحدة التحكم.';

  @override
  String get metadataSessionScope =>
      'الكائنات الدائمة فقط؛ حدّث الكائنات المحلية لوحدة التحكم بعد التنفيذ.';

  @override
  String get metadataLimitScope =>
      'تم بلوغ حد البيانات الوصفية. ضيّق نطاق الكائنات.';

  @override
  String get completeColumnMetadataRequired =>
      'يلزم توفر بيانات وصفية كاملة للأعمدة قبل الاستيراد أو تجهيز التغييرات.';

  @override
  String resizeColumn(String name) {
    return 'تغيير عرض العمود $name';
  }

  @override
  String get keyboardShortcutsHeading => 'اختصارات لوحة المفاتيح';

  @override
  String sqlEditorLabel(String title) {
    return 'محرر SQL ‏$title';
  }

  @override
  String get editorResultsDivider => 'فاصل المحرر والنتائج';

  @override
  String editorExtent(String percent) {
    return 'المحرر بنسبة $percent بالمئة';
  }

  @override
  String get largerEditor => 'تكبير المحرر';

  @override
  String get smallerEditor => 'تصغير المحرر';

  @override
  String get explorerWidthDivider => 'فاصل عرض المستكشف';

  @override
  String get widerExplorer => 'توسيع المستكشف';

  @override
  String get narrowerExplorer => 'تضييق المستكشف';

  @override
  String explorerExtent(String width) {
    return 'العرض $width بكسل';
  }

  @override
  String planTextPage(String start, String end, String total) {
    return '$start–$end من $total وحدة UTF-16';
  }

  @override
  String get dropDesignedColumn => 'حذف العمود';

  @override
  String get liveCatalogLabel => 'الكتالوج الحالي';

  @override
  String get liveSchemaLabel => 'المخطط الحالي';

  @override
  String get searchPathLabel => 'مسار البحث';

  @override
  String get physicalSessionLabel => 'الجلسة الفعلية';

  @override
  String queryTimeoutDetail(String seconds, String rows) {
    return 'المهلة: $seconds ث · حد الصفوف: $rows';
  }

  @override
  String get saveFailedCloseTitle => 'فشل حفظ SQL · إغلاق BusyData';

  @override
  String get createSection => 'إنشاء';

  @override
  String get newConnectionDescription => 'إعداد اتصال بقاعدة بيانات';

  @override
  String get newQueryDescription => 'كتابة SQL في استعلام جديد';

  @override
  String get openSqlDescription => 'فتح مستند SQL موجود';

  @override
  String get searchNoResults => 'لا توجد إجراءات مطابقة';

  @override
  String get actionsCategory => 'الإجراءات';

  @override
  String get privateRecoveryCategory => 'الاسترداد الخاص';

  @override
  String get shortcutRecordHelp =>
      'اضغط اختصارًا. Escape للإلغاء. F6 وShift+F6 محجوزان للتنقل بين الأجزاء.';

  @override
  String get rowLimitInvalid => 'أدخل حد صفوف من 1 إلى 1,000,000.';

  @override
  String get errorPolicy => 'عند خطأ التنفيذ';

  @override
  String get tlsEncrypted => 'مشفر';

  @override
  String get tlsUnencrypted => 'غير مشفر';

  @override
  String get tlsUnobserved => 'لم يُرصد';

  @override
  String get encryptionVerificationNote =>
      'التشفير لا يثبت التحقق من الشهادة أو اسم المضيف.';

  @override
  String get uniqueDesignedColumnName =>
      'استخدم اسم عمود فريدًا؛ تدعم الجداول الجديدة حتى 128 عمودًا';

  @override
  String activityBlockerUnavailable(String id) {
    return 'لم تعد جلسة الحظر $id ظاهرة؛ حدّث وتحقق من أذونات قاعدة البيانات';
  }

  @override
  String get sshChangedKeyReview =>
      'تحقق من المفتاح المتغير بشكل مستقل قبل استبدال ربط ملف التعريف.';

  @override
  String get sshProfileTrustBinding =>
      'تنطبق الثقة على ملف التعريف هذا ونقطة النهاية الدقيقة فقط.';

  @override
  String get databaseTlsEvidence => 'TLS · نظام قاعدة البيانات';

  @override
  String get sshAlgorithmLabel => 'SSH · النوع';

  @override
  String get sshFingerprintLabel => 'SHA-256';

  @override
  String get sshPreviousFingerprintLabel => 'السابق · SHA-256';

  @override
  String get sshReviewedLabel => 'مراجعة مفتاح مضيف SSH';

  @override
  String get shortcutRecordAction => 'تسجيل اختصار';

  @override
  String get fileFormatLabel => 'تنسيق الملف';

  @override
  String get encodingLabel => 'الترميز';

  @override
  String get importPolicyLabel => 'سياسة الاستيراد';

  @override
  String get mainMenu => 'القائمة الرئيسية';

  @override
  String get activityReplyTooLarge => 'تتجاوز استجابة النشاط حد الفاحص.';

  @override
  String get activityListLimited =>
      'القائمة محدودة؛ افحص هدفًا أضيق باستخدام SQL صريح.';

  @override
  String get activitySelectionChanged =>
      'انتهى النشاط المحدد أو تغير. حدد هويته الحالية قبل مراجعة إجراء.';

  @override
  String connectionSavedDraftChanged(String name) {
    return 'تغيّرت حقول الاتصال أثناء الحفظ؛ حُفظ الإعداد: $name. راجع القيم الحالية قبل الاتصال.';
  }

  @override
  String get sshReviewTargetChanged => 'تغيّرت وجهة مراجعة SSH؛ راجعها مجددًا';

  @override
  String get appearance => 'المظهر';

  @override
  String get theme => 'السمة';

  @override
  String get systemTheme => 'النظام';

  @override
  String get lightTheme => 'فاتح';

  @override
  String get darkTheme => 'داكن';

  @override
  String get appLanguage => 'اللغة';

  @override
  String get systemLanguage => 'النظام';

  @override
  String get cut => 'قص';

  @override
  String get paste => 'لصق';

  @override
  String get selectAll => 'تحديد الكل';

  @override
  String get noSelection => 'لا يوجد نص متاح';

  @override
  String get clipboardEmpty => 'لا تحتوي الحافظة على نص';

  @override
  String get settingsDraftNotice =>
      'لم تُحفظ تغييرات التنفيذ والاستعادة الخاصة.';

  @override
  String get documentsMenu => 'المستندات';

  @override
  String get currentSql => 'SQL الحالي';

  @override
  String get searchActionsHint => 'البحث عن إجراءات…';

  @override
  String get searchCurrentSqlHint => 'Search current SQL…';

  @override
  String get searchObjectsHint => 'Search database objects…';

  @override
  String get searchHistoryHint => 'Search query history…';

  @override
  String get metadataAttributes => 'الخصائص';

  @override
  String get metadataSelectionUnavailable =>
      'اختر عنصرًا لفحص خصائصه الملتقطة. التحديد السابق غير متاح.';

  @override
  String get secureStorage => 'تخزين النظام الآمن';

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
      'تعذّر حفظ ذاكرة التخزين المؤقت. لا تزال البيانات الوصفية الحالية متاحة.';

  @override
  String get metadataCacheRebuiltVersion => 'أُعيد الإنشاء للإصدار الحالي';

  @override
  String get metadataCacheRebuiltCorrupt =>
      'أُعيد الإنشاء بعد خطأ في ذاكرة التخزين المؤقت';

  @override
  String get editSessionBusy =>
      'هذه الجلسة مشغولة. انتظر انتهاء العمل الجاري، ثم اطلب تقييمًا جديدًا لقابلية التحرير.';

  @override
  String get editIdentityRequired =>
      'حدّد مفتاحًا أساسيًا كاملًا أو معرّفًا فريدًا لا يقبل NULL قبل التحرير.';

  @override
  String get editColumnsReadOnly =>
      'جميع الأعمدة المحددة مولّدة أو للقراءة فقط.';

  @override
  String get editResultNotReady =>
      'انتظر اكتمال هذه النتيجة المحتفظ بها قبل طلب تقييم جديد لقابلية التحرير.';

  @override
  String get editProjectionUnsupported =>
      'يتطلب التحرير SELECT مباشرًا من جدول أساسي واحد مع تحديد كل عمود أساسي مرة واحدة.';

  @override
  String get sqlInspectionDuplicateUsingColumn => 'عمود مكرر في JOIN USING';

  @override
  String get sqlInspectionUnresolvedUsingColumn =>
      'عمود JOIN USING غير موجود في أحد طرفي الربط';

  @override
  String get sqlInspectionAmbiguousUsingColumn => 'عمود مشترك ملتبس في JOIN';

  @override
  String get sqlInspectionOutputColumnCount =>
      'عدم تطابق عدد أعمدة الإخراج المعلنة';

  @override
  String get sqlInspectionAmbiguousOverload => 'تحميل زائد ملتبس للروتين';

  @override
  String get sqlInspectionBooleanType => 'نوع غير صالح للتعبير المنطقي';

  @override
  String get sqlInspectionOperatorTypes => 'أنواع غير متوافقة لمعاملات العامل';

  @override
  String get sqlInspectionArrayTypes => 'أنواع غير متوافقة لعناصر المصفوفة';

  @override
  String get sqlInspectionCaseConditionType => 'نوع غير متوافق لشرط CASE';

  @override
  String get sqlInspectionCaseResultTypes => 'أنواع غير متوافقة لنتائج CASE';

  @override
  String get sqlInspectionCoalesceTypes => 'أنواع غير متوافقة لوسائط COALESCE';

  @override
  String get sqlInspectionSetColumnCount =>
      'عدم تطابق عدد أعمدة عملية المجموعات';

  @override
  String get sqlInspectionSetTypes =>
      'أنواع غير متوافقة لنتائج عملية المجموعات';

  @override
  String get sqlInspectionRecursiveCteType => 'عدم تطابق نوع CTE العودي';
}
