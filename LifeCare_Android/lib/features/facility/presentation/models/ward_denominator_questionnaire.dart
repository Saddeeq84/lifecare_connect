// Generated from ward denominator.xlsx.
// Keep field names stable because submitted Firestore records use them.

class WardDenominatorChoice {
  final String value;
  final String label;
  final String? department;

  const WardDenominatorChoice(this.value, this.label, {this.department});
}

class WardDenominatorField {
  final String type;
  final String name;
  final String label;
  final bool required;
  final String? choiceList;
  final List<WardDenominatorChoice> choices;

  const WardDenominatorField({
    required this.type,
    required this.name,
    required this.label,
    this.required = false,
    this.choiceList,
    this.choices = const [],
  });
}

const wardDenominatorFields = <WardDenominatorField>[
  WardDenominatorField(
    type: 'select_one',
    name: 'Department',
    label: 'Department',
    choiceList: 'Department',
  ),
  WardDenominatorField(
    type: 'select_one',
    name: 'Ward',
    label: 'Ward',
    choiceList: 'Ward',
  ),
  WardDenominatorField(type: 'date', name: 'Date', label: 'Date'),
  WardDenominatorField(
    type: 'select_one',
    name: 'Surveillance_Day',
    label: 'Surveillance Day',
    choiceList: 'Surveillance_Day',
  ),
  WardDenominatorField(
    type: 'integer',
    name: 'Total_Patients',
    label: 'Total Patients',
  ),
  WardDenominatorField(
    type: 'integer',
    name: 'No_of_New_Admissions',
    label: 'No. of New Admissions',
  ),
  WardDenominatorField(
    type: 'integer',
    name: 'No_of_Discharges',
    label: 'Monthly discharges for selected ward',
  ),
  WardDenominatorField(
    type: 'integer',
    name: 'No_of_Surgical_Procedures',
    label: 'No. of surgical procedures performed',
  ),
  WardDenominatorField(
    type: 'integer',
    name: 'No_of_patients_on_Urinary_Catheter',
    label: 'No. of patients on Urinary Catheter',
  ),
  WardDenominatorField(
    type: 'integer',
    name: 'New_Urinary_Catheter_Insertions',
    label: 'New urinary catheter insertions/placements',
  ),
  WardDenominatorField(
    type: 'integer',
    name: 'No_of_patients_on_C_venous_catheter_CVC',
    label: 'No. of patients on Central venous catheter (CVC)',
  ),
  WardDenominatorField(
    type: 'integer',
    name: 'New_CVC_Insertions',
    label: 'New CVC insertions/placements',
  ),
  WardDenominatorField(
    type: 'integer',
    name: 'No_of_patients_on_P_venous_catheter_PVC',
    label: 'No. of patients on Peripheral venous catheter (PVC)',
  ),
  WardDenominatorField(
    type: 'integer',
    name: 'New_PVC_Insertions',
    label: 'New PVC insertions/placements',
  ),
  WardDenominatorField(
    type: 'integer',
    name: 'No_of_patients_on_I_cal_ventilation_INV',
    label: 'No. of patients on Invasive mechanical ventilation (INV)',
  ),
  WardDenominatorField(
    type: 'integer',
    name: 'New_INV_Insertions',
    label: 'New invasive ventilator starts/placements',
  ),
  WardDenominatorField(
    type: 'integer',
    name: 'No_of_patients_on_N_cal_ventilation_NIV',
    label: 'No. of patients on Non-invasive mechanical ventilation (NIV)',
  ),
  WardDenominatorField(
    type: 'integer',
    name: 'No_Patients_on_NG_Tube',
    label: 'No. Patients on NG Tube',
  ),
  WardDenominatorField(
    type: 'integer',
    name: 'No_Patients_on_Chest_Tube',
    label: 'No. Patients on Chest Tube',
  ),
  WardDenominatorField(
    type: 'integer',
    name: 'No_Patients_on_Surgical_drains',
    label: 'No. Patients on Surgical drains',
  ),
];

const wardDenominatorDepartmentChoices = <WardDenominatorChoice>[
  WardDenominatorChoice('surgery', 'Surgery'),
  WardDenominatorChoice('medicine', 'Medicine'),
  WardDenominatorChoice('paediatric', 'Paediatric'),
  WardDenominatorChoice('obs', 'O&G'),
  WardDenominatorChoice('other', 'Other Unit'),
];

const wardDenominatorWardChoices = <WardDenominatorChoice>[
  WardDenominatorChoice('msw', 'MSW', department: 'surgery'),
  WardDenominatorChoice('fsw', 'FSW', department: 'surgery'),
  WardDenominatorChoice('psw', 'PSW', department: 'surgery'),
  WardDenominatorChoice('mow', 'MOW', department: 'surgery'),
  WardDenominatorChoice('urology', 'Urology', department: 'surgery'),
  WardDenominatorChoice('buns', 'Burns & Plastic', department: 'surgery'),
  WardDenominatorChoice('mmw', 'MMW', department: 'medicine'),
  WardDenominatorChoice('fmw', 'FMW', department: 'medicine'),
  WardDenominatorChoice('pmw', 'PMW', department: 'paediatric'),
  WardDenominatorChoice('scbu', 'SCBU', department: 'paediatric'),
  WardDenominatorChoice('obstetric', 'Obstetric', department: 'obs'),
  WardDenominatorChoice('gynae', 'Gynae', department: 'obs'),
  WardDenominatorChoice('oncology', 'Oncology', department: 'other'),
  WardDenominatorChoice('amenity', 'Amenity', department: 'other'),
  WardDenominatorChoice('isolation', 'Isolation', department: 'other'),
  WardDenominatorChoice('icu', 'ICU', department: 'other'),
];

final wardDenominatorDayChoices = List<WardDenominatorChoice>.generate(
  31,
  (index) => WardDenominatorChoice('day${index + 1}', 'Day${index + 1}'),
);

String wardDenominatorChoiceLabel(String fieldName, Object? value) {
  final raw = '$value';
  final choices = switch (fieldName) {
    'Department' => wardDenominatorDepartmentChoices,
    'Ward' => wardDenominatorWardChoices,
    'Surveillance_Day' => wardDenominatorDayChoices,
    _ => const <WardDenominatorChoice>[],
  };
  return choices
      .firstWhere(
        (choice) => choice.value == raw,
        orElse: () => WardDenominatorChoice(raw, raw),
      )
      .label;
}
