/// App string keys for translations
class AppKeys {
  AppKeys._();

  // App info
  static const String appName = 'app_name';
  static const String appTagline = 'app_tagline';

  // Menu items
  static const String menuHome = 'menu_home';
  static const String menuAppointments = 'menu_appointments';
  static const String menuCases = 'menu_cases';
  static const String menuCustomers = 'menu_customers';
  static const String menuPets = 'menu_pets';
  static const String menuPetshop = 'menu_petshop';
  static const String menuPharmacy = 'menu_pharmacy';
  static const String menuReports = 'menu_reports';
  static const String menuSettings = 'menu_settings';

  // Common actions
  static const String save = 'save';
  static const String cancel = 'cancel';
  static const String delete = 'delete';
  static const String edit = 'edit';
  static const String add = 'add';
  static const String search = 'search';
  static const String filter = 'filter';
  static const String next = 'next';
  static const String previous = 'previous';
  static const String back = 'back';
  static const String confirm = 'confirm';
  static const String close = 'close';
  static const String print = 'print';
  static const String export = 'export';

  // Medical case
  static const String newCase = 'new_case';
  static const String caseNumber = 'case_number';
  static const String admissionDate = 'admission_date';
  static const String dischargeDate = 'discharge_date';
  static const String reasonForVisit = 'reason_for_visit';
  static const String vitalSigns = 'vital_signs';
  static const String clinicalExam = 'clinical_exam';
  static const String diagnosis = 'diagnosis';
  static const String treatment = 'treatment';
  static const String prognosis = 'prognosis';
  static const String payment = 'payment';
  static const String commitment = 'commitment';

  // Prognosis options
  static const String prognosisGood = 'prognosis_good';
  static const String prognosisBad = 'prognosis_bad';
  static const String prognosisUncertain = 'prognosis_uncertain';

  // Result options
  static const String resultRecovered = 'result_recovered';
  static const String resultNotRecovered = 'result_not_recovered';
  static const String resultDied = 'result_died';
  static const String resultUnknown = 'result_unknown';

  // Customer
  static const String customerInfo = 'customer_info';
  static const String customerName = 'customer_name';
  static const String phoneNumber = 'phone_number';
  static const String address = 'address';

  // Pet
  static const String petInfo = 'pet_info';
  static const String petName = 'pet_name';
  static const String species = 'species';
  static const String breed = 'breed';
  static const String age = 'age';
  static const String gender = 'gender';
  static const String weight = 'weight';
  static const String dog = 'dog';
  static const String cat = 'cat';
  static const String male = 'male';
  static const String female = 'female';

  // Vital signs
  static const String temperature = 'temperature';
  static const String digestion = 'digestion';
  static const String vomiting = 'vomiting';
  static const String stool = 'stool';
  static const String mentalStatus = 'mental_status';
  static const String bodyCondition = 'body_condition';
  static const String skinMucosa = 'skin_mucosa';
  static const String otherInfo = 'other_info';

  // Visit reasons (checkboxes)
  static const String vomit = 'vomit';
  static const String weak = 'weak';
  static const String tired = 'tired';
  static const String accident = 'accident';
  static const String fever = 'fever';
  static const String diarrhea = 'diarrhea';
  static const String nopet = 'nopet';
  static const String breath = 'breath';
  static const String itch = 'itch';
  static const String other = 'other';

  // Stool condition
  static const String stoolNormal = 'stool_normal';
  static const String stoolLiquid = 'stool_liquid';
  static const String stoolHard = 'stool_hard';
  static const String stoolBlood = 'stool_blood';

  // Mental status
  static const String mentalAlert = 'mental_alert';
  static const String mentalTired = 'mental_tired';
  static const String mentalLethargic = 'mental_lethargic';
  static const String mentalDrowsy = 'mental_drowsy';
  static const String mentalComa = 'mental_coma';
  static const String mentalRestless = 'mental_restless';
  static const String mentalDepressed = 'mental_depressed'; // Legacy
  static const String mentalExcited = 'mental_excited'; // Legacy

  // Body condition
  static const String bodyNormal = 'body_normal';
  static const String bodyThin = 'body_thin';
  static const String bodyFat = 'body_fat';
  static const String bodyObese = 'body_obese';

  // Services
  static const String services = 'services';
  static const String emergency = 'emergency';
  static const String ultrasound = 'ultrasound';
  static const String xray = 'xray';
  static const String hospitalization = 'hospitalization';
  static const String surgery = 'surgery';
  static const String anesthesia = 'anesthesia';
  static const String medication = 'medication';
  static const String vaccination = 'vaccination';
  static const String checkup = 'checkup';
  static const String totalEstimate = 'total_estimate';

  // Payment
  static const String advancePayment = 'advance_payment';
  static const String paymentMethod = 'payment_method';
  static const String cash = 'cash';
  static const String transfer = 'transfer';
  static const String signature = 'signature';
  static const String customerSignature = 'customer_signature';
  static const String clinicSignature = 'clinic_signature';
  static const String agreeTreatment = 'agree_treatment';
  static const String agreeNoComplaint = 'agree_no_complaint';
  static const String saveCase = 'save_case';
  static const String printCase = 'print_case';

  // Reports
  static const String dailyReport = 'daily_report';
  static const String monthlyReport = 'monthly_report';
  static const String revenue = 'revenue';
  static const String expenses = 'expenses';
  static const String profit = 'profit';
  static const String totalCases = 'total_cases';
  static const String totalCollected = 'total_collected';

  // Pharmacy
  static const String inventory = 'inventory';
  static const String medicineCode = 'medicine_code';
  static const String medicineName = 'medicine_name';
  static const String unit = 'unit';
  static const String stock = 'stock';
  static const String avgPrice = 'avg_price';
  static const String import = 'import';
  static const String export_ = 'export_';
  static const String usageHistory = 'usage_history';

  // Petshop
  static const String products = 'products';
  static const String brand = 'brand';
  static const String salePrice = 'sale_price';
  static const String costPrice = 'cost_price';
  static const String sales = 'sales';

  // Status
  static const String statusActive = 'status_active';
  static const String statusCompleted = 'status_completed';
  static const String statusPending = 'status_pending';
  static const String statusCancelled = 'status_cancelled';

  // Validation messages
  static const String required = 'required';
  static const String invalidPhone = 'invalid_phone';
  static const String invalidEmail = 'invalid_email';

  // Time
  static const String today = 'today';
  static const String thisWeek = 'this_week';
  static const String thisMonth = 'this_month';
  static const String date = 'date';
  static const String time = 'time';
}
