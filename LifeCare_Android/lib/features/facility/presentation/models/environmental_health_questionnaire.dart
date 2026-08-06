// Generated from aQXpooVb2hzmGyFet4HH2h.xlsx.
// Keep field names stable because submitted Firestore records use them.

class EnvironmentalSurveyChoice {
  final String value;
  final String label;

  const EnvironmentalSurveyChoice(this.value, this.label);
}

class EnvironmentalSurveyQuestion {
  final String type;
  final String name;
  final String label;
  final String? hint;
  final bool required;
  final String? relevant;
  final List<EnvironmentalSurveyChoice> choices;

  const EnvironmentalSurveyQuestion({
    required this.type,
    required this.name,
    required this.label,
    this.hint,
    this.required = false,
    this.relevant,
    this.choices = const [],
  });
}

const environmentalHealthQuestions = <EnvironmentalSurveyQuestion>[
  EnvironmentalSurveyQuestion(
    type: 'select_one',
    name: 'Department_Unit',
    label: '1. Department/Unit',
    required: true,
    choices: [
      EnvironmentalSurveyChoice('medical_department', 'Medical Department'),
      EnvironmentalSurveyChoice('surgical_department', 'Surgical Department'),
      EnvironmentalSurveyChoice('o_g_department', 'O&G Department'),
      EnvironmentalSurveyChoice(
        'paediatric_department',
        'Paediatric Department',
      ),
      EnvironmentalSurveyChoice(
        'department_of_family_medicine',
        'Emergency Departments/Units',
      ),
      EnvironmentalSurveyChoice(
        'community_medicine_department',
        'Community Medicine Department',
      ),
      EnvironmentalSurveyChoice('ent_department', 'ENT Department'),
      EnvironmentalSurveyChoice(
        'physiotherapy_department',
        'Physiotherapy Department',
      ),
      EnvironmentalSurveyChoice(
        'maxillofacial_department',
        'Maxillofacial Department',
      ),
      EnvironmentalSurveyChoice(
        'main_operating_theater',
        'Main Operating Theater',
      ),
      EnvironmentalSurveyChoice('obstetric_theater', 'Obstetric Theater'),
      EnvironmentalSurveyChoice('ophthalmic_complex', 'Ophthalmic Complex'),
      EnvironmentalSurveyChoice('radiology_department', 'Radiology Department'),
      EnvironmentalSurveyChoice('other_wards_units', 'Other Wards'),
      EnvironmentalSurveyChoice(
        'other_special_clinics',
        'Other Special Clinics',
      ),
      EnvironmentalSurveyChoice(
        'medical_microbiology_departmen',
        'Medical Microbiology Department',
      ),
      EnvironmentalSurveyChoice(
        'chemical_pathology_department',
        'Chemical Pathology Department ',
      ),
      EnvironmentalSurveyChoice(
        'haematology_department',
        'Haematology Department',
      ),
      EnvironmentalSurveyChoice(
        'histopathology_department',
        'Histopathology Department ',
      ),
      EnvironmentalSurveyChoice('laundry_unit', 'Laundry Unit'),
    ],
  ),
  EnvironmentalSurveyQuestion(
    type: 'select_one',
    name: '_2_Medical_Wards_Clinics',
    label: '2. Medical Wards/Clinics',
    required: true,
    relevant: '\${Department_Unit} = \'medical_department\'',
    choices: [
      EnvironmentalSurveyChoice('male_medical_ward', 'Male Medical Ward'),
      EnvironmentalSurveyChoice('female_medical_ward', 'Female Medical Ward'),
      EnvironmentalSurveyChoice('isolation_ward', 'Isolation Ward'),
      EnvironmentalSurveyChoice('dialysis_unit', 'Dialysis Ward'),
    ],
  ),
  EnvironmentalSurveyQuestion(
    type: 'select_one',
    name: '_3_Surgical_Wards_Clinic',
    label: '3. Surgical Wards/Clinic',
    required: true,
    relevant: '\${Department_Unit} = \'surgical_department\'',
    choices: [
      EnvironmentalSurveyChoice('male_surgical_ward', 'Male Surgical Ward'),
      EnvironmentalSurveyChoice('female_surgical_ward', 'Female Surgical Ward'),
      EnvironmentalSurveyChoice(
        'paediatric_surgical_ward',
        'Paediatric Surgical Ward',
      ),
      EnvironmentalSurveyChoice('male_orthopedic_ward', 'Male Orthopedic Ward'),
      EnvironmentalSurveyChoice('burns___plastic_ward', 'Burns & Plastic Ward'),
      EnvironmentalSurveyChoice('urology_ward', 'Urology Ward'),
    ],
  ),
  EnvironmentalSurveyQuestion(
    type: 'select_one',
    name: '_4_O_G_Wards_Units',
    label: '4. O&G Wards/Units',
    required: true,
    relevant: '\${Department_Unit} = \'o_g_department\'',
    choices: [
      EnvironmentalSurveyChoice('obstetric_ward', 'Obstetric Ward'),
      EnvironmentalSurveyChoice('gynaecology_ward', 'Gynaecology ward'),
      EnvironmentalSurveyChoice('labour_room', 'Labour Room'),
    ],
  ),
  EnvironmentalSurveyQuestion(
    type: 'select_one',
    name: 'Paediatric_Wards_Clinics',
    label: '5. Paediatric Wards/Clinics',
    required: true,
    relevant: '\${Department_Unit} = \'paediatric_department\'',
    choices: [
      EnvironmentalSurveyChoice(
        'pediatric_medical_ward',
        'Pediatric Medical Ward',
      ),
      EnvironmentalSurveyChoice('scbu__in_born', 'SCBU (In Born)'),
      EnvironmentalSurveyChoice('scbu__out_born', 'SCBU (Out Born)'),
      EnvironmentalSurveyChoice('epu', 'EPU'),
    ],
  ),
  EnvironmentalSurveyQuestion(
    type: 'select_one',
    name: '_6_Emergency_Units',
    label: '6. Emergency Units',
    required: true,
    relevant: '\${Department_Unit} = \'department_of_family_medicine\'',
    choices: [
      EnvironmentalSurveyChoice('a_e_medical', 'A&E Medical'),
      EnvironmentalSurveyChoice('a_e_surgical', 'A&E Surgical'),
      EnvironmentalSurveyChoice('gopc', 'Gynae Emergency'),
      EnvironmentalSurveyChoice('nhis_clinic', 'Obstetric Emergency'),
    ],
  ),
  EnvironmentalSurveyQuestion(
    type: 'select_one',
    name: 'Community_Medicine_Units',
    label: '7. Community Medicine Units',
    required: true,
    relevant: '\${Department_Unit} = \'community_medicine_department\'',
    choices: [
      EnvironmentalSurveyChoice(
        'general_area',
        'General Area/Offices/Reception',
      ),
      EnvironmentalSurveyChoice('immunization_unit', 'Immunization Unit'),
      EnvironmentalSurveyChoice('incineration_room', 'Incineration Room'),
      EnvironmentalSurveyChoice('dump_site', 'Dump Site'),
    ],
  ),
  EnvironmentalSurveyQuestion(
    type: 'select_one',
    name: '_8_ENT_Units',
    label: '8. ENT Units',
    required: true,
    relevant: '\${Department_Unit} = \'ent_department\'',
    choices: [
      EnvironmentalSurveyChoice('general_area', 'General Area/Reception'),
      EnvironmentalSurveyChoice('option_1', 'Audiology'),
      EnvironmentalSurveyChoice('option_2', 'Endoscopy Room'),
      EnvironmentalSurveyChoice('bone_dissection_room', 'Bone Dissection Room'),
    ],
  ),
  EnvironmentalSurveyQuestion(
    type: 'select_one',
    name: '_9_Physiotherapy_Units',
    label: '9. Physiotherapy Units',
    required: true,
    relevant: '\${Department_Unit} = \'physiotherapy_department\'',
    choices: [
      EnvironmentalSurveyChoice(
        'general_area__including_toilets',
        'General Area/Reception',
      ),
      EnvironmentalSurveyChoice('paediatic_unit', 'Surgery/Orthopaedic Unit'),
      EnvironmentalSurveyChoice('option_2', 'Medicine/Neurology Unit'),
      EnvironmentalSurveyChoice('child_health_unit', 'Child Health Unit'),
      EnvironmentalSurveyChoice('treatment_room', 'Treatment Room'),
      EnvironmentalSurveyChoice('plaster_ot_p_o_room', 'Plaster/OT/P&O Room'),
    ],
  ),
  EnvironmentalSurveyQuestion(
    type: 'select_one',
    name: '_10_Maxillofacial_Units',
    label: '10. Maxillofacial Units',
    required: true,
    relevant: '\${Department_Unit} = \'maxillofacial_department\'',
    choices: [
      EnvironmentalSurveyChoice(
        'general_area_reception',
        'General Area/Reception',
      ),
      EnvironmentalSurveyChoice('option_1', 'Surgical Room General'),
      EnvironmentalSurveyChoice('sterilization_room', 'Sterilization Room'),
      EnvironmentalSurveyChoice('denture_room', 'Denture Room'),
    ],
  ),
  EnvironmentalSurveyQuestion(
    type: 'select_one',
    name: 'MOT_Units',
    label: '11. MOT Units',
    required: true,
    relevant: '\${Department_Unit} = \'main_operating_theater\'',
    choices: [
      EnvironmentalSurveyChoice('general_area', 'General Area/Reception'),
      EnvironmentalSurveyChoice('suite_1', 'Theater Suites'),
      EnvironmentalSurveyChoice('recovery_room', 'Recovery Room'),
      EnvironmentalSurveyChoice('a_e_suite', 'A&E Suite'),
      EnvironmentalSurveyChoice(
        'central_sterile_supply_unit',
        'Central Sterile Supply Unit',
      ),
    ],
  ),
  EnvironmentalSurveyQuestion(
    type: 'select_one',
    name: '_12_O_G_Theater_Units',
    label: '12. O&G Theater Units',
    required: true,
    relevant: '\${Department_Unit} = \'obstetric_theater\'',
    choices: [
      EnvironmentalSurveyChoice('suite_1', 'General Area'),
      EnvironmentalSurveyChoice('suite_2', 'Suites'),
    ],
  ),
  EnvironmentalSurveyQuestion(
    type: 'select_one',
    name: '_13_Other_Wards_Units',
    label: '13. Other Wards/Units',
    required: true,
    relevant: '\${Department_Unit} = \'other_wards_units\'',
    choices: [
      EnvironmentalSurveyChoice('icu', 'ICU'),
      EnvironmentalSurveyChoice('amenity_ward', 'Amenity Ward'),
      EnvironmentalSurveyChoice('oncology_ward', 'Oncology Ward'),
    ],
  ),
  EnvironmentalSurveyQuestion(
    type: 'select_one',
    name: 'Haematology_Units',
    label: '14. Haematology Units',
    required: true,
    relevant: '\${Department_Unit} = \'haematology_department\'',
    choices: [
      EnvironmentalSurveyChoice(
        'general_area__including_toilets',
        'General Area/Reception/Sample collection',
      ),
      EnvironmentalSurveyChoice('bleeding_room', 'Bleeding Room'),
    ],
  ),
  EnvironmentalSurveyQuestion(
    type: 'select_one',
    name: 'Chemical_Pathology_Units',
    label: '15. Chemical Pathology Units',
    required: true,
    relevant: '\${Department_Unit} = \'chemical_pathology_department\'',
    choices: [
      EnvironmentalSurveyChoice(
        'general_area__including_toilets',
        'General Area/Reception/Sample Collection',
      ),
      EnvironmentalSurveyChoice('processing_unit', 'Processing Unit'),
      EnvironmentalSurveyChoice('metabolic_unit', 'Metabolic Unit'),
    ],
  ),
  EnvironmentalSurveyQuestion(
    type: 'select_one',
    name: 'Histopathology_Units',
    label: '16. Histopathology Units',
    required: true,
    relevant: '\${Department_Unit} = \'histopathology_department\'',
    choices: [
      EnvironmentalSurveyChoice(
        'general_area__including_toilets',
        'General Area/Reception/Sample Collection',
      ),
      EnvironmentalSurveyChoice('processing_room', 'Processing Room'),
      EnvironmentalSurveyChoice('mortuary', 'Mortuary'),
    ],
  ),
  EnvironmentalSurveyQuestion(
    type: 'select_one',
    name: 'Medical_Microbiology_Units',
    label: '17. Medical Microbiology Units',
    required: true,
    relevant: '\${Department_Unit} = \'medical_microbiology_departmen\'',
    choices: [
      EnvironmentalSurveyChoice(
        'general_area',
        'General Area/Reception/Sample Collection',
      ),
      EnvironmentalSurveyChoice('bacteriology_unit', 'Bacteriology Unit'),
      EnvironmentalSurveyChoice('serology_unit', 'Serology Unit'),
      EnvironmentalSurveyChoice('molecular_lab', 'Molecular Lab'),
      EnvironmentalSurveyChoice('stc_unit', 'STC Unit'),
      EnvironmentalSurveyChoice('wash_room', 'Wash Room'),
      EnvironmentalSurveyChoice('genxpert', 'GenXpert'),
    ],
  ),
  EnvironmentalSurveyQuestion(
    type: 'select_one',
    name: '_18_Other_Special_Clinics',
    label: '18. Other Special Clinics',
    required: true,
    relevant: '\${Department_Unit} = \'other_special_clinics\'',
    choices: [
      EnvironmentalSurveyChoice('sickle_cell_clinic', 'Sickle Cell Clinic'),
      EnvironmentalSurveyChoice('endoscopy_room__mmw', 'Endoscopy Room (MMW)'),
      EnvironmentalSurveyChoice('art_clinic', 'ART Clinic'),
      EnvironmentalSurveyChoice('mopd_sopd_clinic', 'MOPD/SOPD Clinic'),
      EnvironmentalSurveyChoice('labour_room', 'Labour Room'),
      EnvironmentalSurveyChoice('o_g_clinic', 'O&G Clinic'),
      EnvironmentalSurveyChoice('paediatric_complex', 'Paediatric Complex'),
      EnvironmentalSurveyChoice('gopc', 'GOPC'),
      EnvironmentalSurveyChoice('nhis_clinic', 'NHIS Clinic'),
    ],
  ),
  EnvironmentalSurveyQuestion(
    type: 'note',
    name: 'General_Area_Assessment',
    label: 'General Area Assessment',
  ),
  EnvironmentalSurveyQuestion(
    type: 'select_one',
    name: '_19_Are_floors_and_general_are',
    label: '19. Are floors and general areas cleaned daily?',
    required: true,
    choices: [
      EnvironmentalSurveyChoice('yes', 'Yes'),
      EnvironmentalSurveyChoice('no', 'No'),
    ],
  ),
  EnvironmentalSurveyQuestion(
    type: 'select_one',
    name: 'How_frequent_are_the_floor_cle',
    label: 'How frequent are the floor cleaned?',
    required: true,
    relevant: '\${_19_Are_floors_and_general_are} = \'yes\'',
    choices: [
      EnvironmentalSurveyChoice('at_least_twice_daily', 'At least twice daily'),
      EnvironmentalSurveyChoice('once_daily', 'Once Daily'),
      EnvironmentalSurveyChoice('every_shift', 'Every Shift'),
      EnvironmentalSurveyChoice('on_demand', 'On Demand'),
      EnvironmentalSurveyChoice('others__specify', 'Others (Specify)'),
    ],
  ),
  EnvironmentalSurveyQuestion(
    type: 'text',
    name: 'Please_Specify',
    label: 'Please Specify:',
    required: true,
    relevant: '\${How_frequent_are_the_floor_cle} = \'others__specify\'',
  ),
  EnvironmentalSurveyQuestion(
    type: 'select_one',
    name: '_20_Are_there_separate_toilet_',
    label: '20. Are there separate toilet/sanitary facilities for Staff?',
    required: true,
    relevant:
        '\${Department_Unit} = \'medical_department\' or \${Department_Unit} = \'surgical_department\' or \${Department_Unit} = \'o_g_department\' or \${Department_Unit} = \'paediatric_department\' or \${Department_Unit} = \'department_of_family_medicine\' or \${Community_Medicine_Units} = \'general_area\' or \${_8_ENT_Units} = \'general_area\' or \${_9_Physiotherapy_Units} = \'general_area__including_toilets\' or \${_10_Maxillofacial_Units} = \'general_area_reception\' or \${MOT_Units} = \'general_area\' or \${Haematology_Units} = \'general_area__including_toilets\' or \${Chemical_Pathology_Units} = \'general_area__including_toilets\' or \${Histopathology_Units} = \'general_area__including_toilets\' or \${Medical_Microbiology_Units} = \'general_area\'',
    choices: [
      EnvironmentalSurveyChoice('yes', 'Yes'),
      EnvironmentalSurveyChoice('no', 'No'),
    ],
  ),
  EnvironmentalSurveyQuestion(
    type: 'select_one',
    name: '_21_Are_there_separate_toilet_',
    label: '21. Are there separate toilet/Sanitary facilities for patients?',
    required: true,
    relevant:
        '\${Department_Unit} = \'medical_department\' or \${Department_Unit} = \'surgical_department\' or \${Department_Unit} = \'o_g_department\' or \${Department_Unit} = \'paediatric_department\' or \${Department_Unit} = \'department_of_family_medicine\' or \${_8_ENT_Units} = \'general_area\' or \${Community_Medicine_Units} = \'general_area\' or \${_9_Physiotherapy_Units} = \'general_area__including_toilets\' or \${_10_Maxillofacial_Units} = \'general_area_reception\' or \${MOT_Units} = \'general_area\' or \${Haematology_Units} = \'general_area__including_toilets\' or \${Chemical_Pathology_Units} = \'general_area__including_toilets\' or \${Histopathology_Units} = \'general_area__including_toilets\' or \${Medical_Microbiology_Units} = \'general_area\'',
    choices: [
      EnvironmentalSurveyChoice('yes', 'Yes'),
      EnvironmentalSurveyChoice('no', 'No'),
    ],
  ),
  EnvironmentalSurveyQuestion(
    type: 'select_one',
    name: '_22_Are_hand_hygiene_point_si',
    label:
        '22. Are hand hygiene point (sink) available and functional in all the toilets?',
    required: true,
    relevant: '\${_21_Are_there_separate_toilet_} = \'yes\'',
    choices: [
      EnvironmentalSurveyChoice('yes', 'Yes'),
      EnvironmentalSurveyChoice('no', 'No'),
    ],
  ),
  EnvironmentalSurveyQuestion(
    type: 'select_one',
    name: '_23_Are_soup_available_at_hand',
    label: '23. Are soup available at hand hygiene point in the toilets?',
    required: true,
    relevant: '\${_22_Are_hand_hygiene_point_si} = \'yes\'',
    choices: [
      EnvironmentalSurveyChoice('yes', 'Yes'),
      EnvironmentalSurveyChoice('no', 'No'),
    ],
  ),
  EnvironmentalSurveyQuestion(
    type: 'select_one',
    name: '_24_Are_water_available_at_han',
    label: '24. Are water available at hand hygiene points in the toilets?',
    required: true,
    relevant: '\${_23_Are_soup_available_at_hand} = \'yes\'',
    choices: [
      EnvironmentalSurveyChoice('yes', 'Yes'),
      EnvironmentalSurveyChoice('no', 'No'),
    ],
  ),
  EnvironmentalSurveyQuestion(
    type: 'select_one',
    name: '_25_Are_waste_bins_available_at_toilets',
    label: '25. Are waste bins available at toilets?',
    required: true,
    relevant: '\${_24_Are_water_available_at_han} = \'yes\'',
    choices: [
      EnvironmentalSurveyChoice('yes', 'Yes'),
      EnvironmentalSurveyChoice('no', 'No'),
    ],
  ),
  EnvironmentalSurveyQuestion(
    type: 'select_one',
    name: '_26_Are_there_separa_s_for_disable_people',
    label:
        '26. Are there separate toilet/sanitary facilities for disable people?',
    required: true,
    relevant: '\${_21_Are_there_separate_toilet_} = \'yes\'',
    choices: [
      EnvironmentalSurveyChoice('yes', 'Yes'),
      EnvironmentalSurveyChoice('no', 'No'),
    ],
  ),
  EnvironmentalSurveyQuestion(
    type: 'select_one',
    name: '_27_Are_masks_availa_respiratory_symptoms',
    label: '27. Are masks available for patients with respiratory symptoms?',
    required: true,
    relevant:
        '\${Department_Unit} = \'other_special_clinics\' or \${Department_Unit} = \'department_of_family_medicine\' or \${Community_Medicine_Units} = \'immunization_unit\' or \${_8_ENT_Units} = \'general_area\' or \${_10_Maxillofacial_Units} = \'general_area_reception\' or \${_9_Physiotherapy_Units} = \'general_area__including_toilets\' or \${Department_Unit} = \'ophthalmic_complex\' or \${Department_Unit} = \'radiology_department\'',
    choices: [
      EnvironmentalSurveyChoice('yes', 'Yes'),
      EnvironmentalSurveyChoice('no', 'No'),
    ],
  ),
  EnvironmentalSurveyQuestion(
    type: 'select_one',
    name: '_28_Are_posters_on_c_yed_in_patient_areas',
    label: '28. Are posters on cough etiquette displayed in patient areas?',
    required: true,
    relevant:
        '\${Department_Unit} = \'department_of_family_medicine\' or \${Community_Medicine_Units} = \'immunization_unit\' or \${_8_ENT_Units} = \'general_area\' or \${_9_Physiotherapy_Units} = \'general_area__including_toilets\' or \${_10_Maxillofacial_Units} = \'general_area_reception\' or \${Department_Unit} = \'other_special_clinics\'',
    choices: [
      EnvironmentalSurveyChoice('yes', 'Yes'),
      EnvironmentalSurveyChoice('no', 'No'),
    ],
  ),
  EnvironmentalSurveyQuestion(
    type: 'select_one',
    name: '_29_Are_toilets_floo_sinks_visibly_clean',
    label:
        '29. Are toilets floors, squads and hand hygiene sinks visibly clean?',
    required: true,
    relevant:
        '\${_20_Are_there_separate_toilet_} = \'yes\' or \${_21_Are_there_separate_toilet_} = \'yes\'',
    choices: [
      EnvironmentalSurveyChoice('yes', 'Yes'),
      EnvironmentalSurveyChoice('no', 'No'),
    ],
  ),
  EnvironmentalSurveyQuestion(
    type: 'select_one',
    name: '_30_Are_physical_dis_iting_areas_adequate',
    label:
        '30. Are physical distancing and ventilation in waiting areas adequate?',
    required: true,
    relevant:
        '\${Department_Unit} = \'other_special_clinics\' or \${Department_Unit} = \'department_of_family_medicine\' or \${_9_Physiotherapy_Units} = \'general_area__including_toilets\' or \${_8_ENT_Units} = \'general_area\' or \${Community_Medicine_Units} = \'immunization_unit\' or \${Histopathology_Units} = \'general_area__including_toilets\' or \${_10_Maxillofacial_Units} = \'general_area_reception\' or \${Haematology_Units} = \'general_area__including_toilets\' or \${Chemical_Pathology_Units} = \'general_area__including_toilets\' or \${Histopathology_Units} = \'general_area__including_toilets\' or \${Medical_Microbiology_Units} = \'general_area\'',
    choices: [
      EnvironmentalSurveyChoice('yes', 'Yes'),
      EnvironmentalSurveyChoice('no', 'No'),
    ],
  ),
  EnvironmentalSurveyQuestion(
    type: 'select_one',
    name: '_31_Are_the_window_f_no_spills_and_stains',
    label:
        '31. Are the window frames and nets visibly clean with no spills and stains?',
    required: true,
    relevant:
        '\${Department_Unit} = \'medical_department\' or \${Department_Unit} = \'surgical_department\' or \${Department_Unit} = \'o_g_department\' or \${Department_Unit} = \'paediatric_department\' or \${Department_Unit} = \'department_of_family_medicine\' or \${Department_Unit} = \'main_operating_theater\' or \${Department_Unit} = \'other_wards_units\' or \${Department_Unit} = \'other_special_clinics\'',
    choices: [
      EnvironmentalSurveyChoice('yes', 'Yes'),
      EnvironmentalSurveyChoice('no', 'No'),
    ],
  ),
  EnvironmentalSurveyQuestion(
    type: 'select_one',
    name: '_32_Are_rooms_and_co_l_lit_and_ventilated',
    label: '32. Are rooms and corridors well lit and ventilated?',
    required: true,
    relevant:
        '\${Department_Unit} = \'medical_department\' or \${Department_Unit} = \'surgical_department\' or \${Department_Unit} = \'o_g_department\' or \${Department_Unit} = \'paediatric_department\' or \${Department_Unit} = \'department_of_family_medicine\' or \${Department_Unit} = \'other_wards_units\' or \${Department_Unit} = \'other_special_clinics\'',
    choices: [
      EnvironmentalSurveyChoice('yes', 'Yes'),
      EnvironmentalSurveyChoice('no', 'No'),
    ],
  ),
  EnvironmentalSurveyQuestion(
    type: 'note',
    name: 'Patient_Care_Area',
    label: 'Patient Care Area',
    relevant:
        '\${Department_Unit} = \'medical_department\' or \${Department_Unit} = \'surgical_department\' or \${Department_Unit} = \'o_g_department\' or \${Department_Unit} = \'paediatric_department\' or \${Department_Unit} = \'other_wards_units\' or \${Department_Unit} = \'department_of_family_medicine\' or \${Department_Unit} = \'other_special_clinics\' or \${Department_Unit} = \'ent_department\' or \${Department_Unit} = \'physiotherapy_department\' or \${Department_Unit} = \'maxillofacial_department\' or \${Department_Unit} = \'ophthalmic_complex\' or \${Department_Unit} = \'radiology_department\' or \${Department_Unit} = \'medical_microbiology_departmen\' or \${Department_Unit} = \'chemical_pathology_department\' or \${Department_Unit} = \'haematology_department\' or \${Department_Unit} = \'histopathology_department\'',
  ),
  EnvironmentalSurveyQuestion(
    type: 'integer',
    name: '_33_How_many_patient_urrently_on_the_ward',
    label: '33. How many patients are currently on the ward?',
    required: true,
    relevant:
        '\${Department_Unit} = \'medical_department\' or \${Department_Unit} = \'surgical_department\' or \${Department_Unit} = \'o_g_department\' or \${Department_Unit} = \'paediatric_department\' or \${Department_Unit} = \'department_of_family_medicine\' or \${Department_Unit} = \'other_wards_units\'',
  ),
  EnvironmentalSurveyQuestion(
    type: 'note',
    name: 'Dialysis_ICU_Isolation_care',
    label: 'Dialysis/ICU/Isolation care',
    relevant: '\${_2_Medical_Wards_Clinics} = \'dialysis_unit\'',
  ),
  EnvironmentalSurveyQuestion(
    type: 'select_one',
    name: '_34_Is_there_a_dedic_ve_HIV_patients_etc',
    label:
        '34. Is there a dedicated machine for Infectious diseases (Hepatitis B-positive, HIV patients etc)?',
    required: true,
    relevant: '\${_2_Medical_Wards_Clinics} = \'dialysis_unit\'',
    choices: [
      EnvironmentalSurveyChoice('yes', 'Yes'),
      EnvironmentalSurveyChoice('no', 'No'),
    ],
  ),
  EnvironmentalSurveyQuestion(
    type: 'select_one',
    name: '_35_Is_the_dialysis_d_after_each_session',
    label: '35. Is the dialysis machine disinfected after each session?',
    required: true,
    relevant: '\${_2_Medical_Wards_Clinics} = \'dialysis_unit\'',
    choices: [
      EnvironmentalSurveyChoice('yes', 'Yes'),
      EnvironmentalSurveyChoice('no', 'No'),
    ],
  ),
  EnvironmentalSurveyQuestion(
    type: 'select_one',
    name: '_36_Is_the_water_tre_ested_and_documented',
    label: '36. Is the water treatment system regularly tested and documented?',
    required: true,
    relevant: '\${_2_Medical_Wards_Clinics} = \'dialysis_unit\'',
    choices: [
      EnvironmentalSurveyChoice('yes', 'Yes'),
      EnvironmentalSurveyChoice('no', 'No'),
    ],
  ),
  EnvironmentalSurveyQuestion(
    type: 'select_one',
    name: '_37_Are_invasive_dev_daily_for_necessity',
    label:
        '37. Are invasive devices (e.g., catheters, ventilators) assessed daily for necessity?',
    required: true,
    relevant:
        '\${_2_Medical_Wards_Clinics} = \'dialysis_unit\' or \${_13_Other_Wards_Units} = \'icu\'',
    choices: [
      EnvironmentalSurveyChoice('yes', 'Yes'),
      EnvironmentalSurveyChoice('no', 'No'),
    ],
  ),
  EnvironmentalSurveyQuestion(
    type: 'select_one',
    name: '_38_Are_sterile_proc_ntral_line_insertion',
    label: '38. Are sterile procedures used for central line insertion?',
    required: true,
    relevant:
        '\${_2_Medical_Wards_Clinics} = \'dialysis_unit\' or \${_13_Other_Wards_Units} = \'icu\'',
    choices: [
      EnvironmentalSurveyChoice('yes', 'Yes'),
      EnvironmentalSurveyChoice('no', 'No'),
    ],
  ),
  EnvironmentalSurveyQuestion(
    type: 'select_one',
    name: '_39_Are_ventilator_c_tocol_not_routinely',
    label: '39. Are ventilator circuits changed per protocol, not routinely?',
    required: true,
    relevant: '\${_13_Other_Wards_Units} = \'icu\'',
    choices: [
      EnvironmentalSurveyChoice('yes', 'Yes'),
      EnvironmentalSurveyChoice('no', 'No'),
    ],
  ),
  EnvironmentalSurveyQuestion(
    type: 'select_one',
    name: '_40_Are_isolation_si_yed_on_patient_doors',
    label:
        '40. Are isolation signs (droplet/contact/airborne) clearly displayed on patient doors?',
    required: true,
    relevant: '\${_2_Medical_Wards_Clinics} = \'isolation_ward\'',
    choices: [
      EnvironmentalSurveyChoice('yes', 'Yes'),
      EnvironmentalSurveyChoice('no', 'No'),
    ],
  ),
  EnvironmentalSurveyQuestion(
    type: 'select_one',
    name: '_41_Are_isolation_ro_and_hygiene_stations',
    label:
        '41. Are isolation rooms equipped with functional hand hygiene stations?',
    required: true,
    relevant: '\${_2_Medical_Wards_Clinics} = \'isolation_ward\'',
    choices: [
      EnvironmentalSurveyChoice('yes', 'Yes'),
      EnvironmentalSurveyChoice('no', 'No'),
    ],
  ),
  EnvironmentalSurveyQuestion(
    type: 'select_one',
    name: '_42_Are_isolation_ro_ressure_if_airborne',
    label:
        '42. Are isolation rooms well-ventilated or equipped with negative pressure (if airborne)?',
    required: true,
    relevant: '\${_2_Medical_Wards_Clinics} = \'isolation_ward\'',
    choices: [
      EnvironmentalSurveyChoice('yes', 'Yes'),
      EnvironmentalSurveyChoice('no', 'No'),
    ],
  ),
  EnvironmentalSurveyQuestion(
    type: 'note',
    name: 'Hand_Hygiene',
    label: 'Hand Hygiene ',
  ),
  EnvironmentalSurveyQuestion(
    type: 'select_one',
    name: '_34_Are_hand_hygiene_stations_',
    label:
        '43. Are hand hygiene stations (e.g., sinks or ABHR dispensers) available and functional?',
    required: true,
    choices: [
      EnvironmentalSurveyChoice('yes', 'Yes'),
      EnvironmentalSurveyChoice('no', 'No'),
    ],
  ),
  EnvironmentalSurveyQuestion(
    type: 'select_one',
    name: '_44_Are_hand_hygiene_ed_at_points_of_care',
    label: '44. Are hand hygiene posters displayed at points of care?',
    required: true,
    relevant: '\${_34_Are_hand_hygiene_stations_} = \'yes\'',
    choices: [
      EnvironmentalSurveyChoice('yes', 'Yes'),
      EnvironmentalSurveyChoice('no', 'No'),
    ],
  ),
  EnvironmentalSurveyQuestion(
    type: 'select_one',
    name: '_45_Are_water_Availa_rvice_points_of_care',
    label: '45. Are water Available at Service points of care?',
    required: true,
    relevant: '\${_34_Are_hand_hygiene_stations_} = \'yes\'',
    choices: [
      EnvironmentalSurveyChoice('yes', 'Yes'),
      EnvironmentalSurveyChoice('no', 'No'),
    ],
  ),
  EnvironmentalSurveyQuestion(
    type: 'select_one',
    name: '_46_Are_Soup_Available_at_Service_Point',
    label: '46. Are Soup Available at Service Point?',
    required: true,
    relevant: '\${_34_Are_hand_hygiene_stations_} = \'yes\'',
    choices: [
      EnvironmentalSurveyChoice('yes', 'Yes'),
      EnvironmentalSurveyChoice('no', 'No'),
    ],
  ),
  EnvironmentalSurveyQuestion(
    type: 'select_one',
    name: 'Are_alcohol_based_hand_rubs_A',
    label:
        '47. Are alcohol-based hand rubs (ABHRs) available at each patient bedside?',
    required: true,
    relevant:
        '\${Department_Unit} = \'medical_department\' or \${Department_Unit} = \'surgical_department\' or \${Department_Unit} = \'o_g_department\' or \${Department_Unit} = \'paediatric_department\' or \${Department_Unit} = \'other_wards_units\' or \${Department_Unit} = \'department_of_family_medicine\'',
    choices: [
      EnvironmentalSurveyChoice('yes', 'Yes'),
      EnvironmentalSurveyChoice('no', 'No'),
    ],
  ),
  EnvironmentalSurveyQuestion(
    type: 'text',
    name: '_48_What_is_the_numb_lability_at_bed_side',
    label: '48. What is the number of ABHR Availability at bed side?',
    hint: 'e.g. (2 out of 10 occupied beds)',
    required: true,
    relevant: '\${Are_alcohol_based_hand_rubs_A} = \'yes\'',
  ),
  EnvironmentalSurveyQuestion(
    type: 'select_one',
    name: '_49_Are_Water_Supply_vailable_at_all_time',
    label: '49. Are Water Supply Available at all time?',
    required: true,
    relevant: '\${_34_Are_hand_hygiene_stations_} = \'yes\'',
    choices: [
      EnvironmentalSurveyChoice('yes', 'Yes'),
      EnvironmentalSurveyChoice('yes__sometimes', 'Yes, Sometimes'),
      EnvironmentalSurveyChoice('no', 'No'),
    ],
  ),
  EnvironmentalSurveyQuestion(
    type: 'select_one',
    name: '_50_If_not_every_bed_with_10_bed_spaces',
    label:
        '50. If not every bed has ABHR, Are hand hygiene point available at each cubicle (with 10 bed spaces)?',
    required: true,
    relevant: '\${Are_alcohol_based_hand_rubs_A} = \'no\'',
    choices: [
      EnvironmentalSurveyChoice('yes', 'Yes'),
      EnvironmentalSurveyChoice('no', 'No'),
    ],
  ),
  EnvironmentalSurveyQuestion(
    type: 'note',
    name: 'PPE_Use_and_Availability',
    label: 'PPE Use and Availability',
  ),
  EnvironmentalSurveyQuestion(
    type: 'select_one',
    name: '_42_Are_PPE_gloves_masks_ap',
    label:
        '51. Are PPE (gloves, masks, aprons, gowns) available at the point of care?',
    required: true,
    choices: [
      EnvironmentalSurveyChoice('yes', 'Yes'),
      EnvironmentalSurveyChoice('no', 'No'),
    ],
  ),
  EnvironmentalSurveyQuestion(
    type: 'select_one',
    name: '_43_Are_staff_observed_using_P',
    label:
        '52. Are staff observed using PPE appropriately when indicated/Based on exposure risk level? (e.g., gloves for contact, N95 for aerosol)',
    required: true,
    relevant: '\${_42_Are_PPE_gloves_masks_ap} = \'yes\'',
    choices: [
      EnvironmentalSurveyChoice('always', 'Always'),
      EnvironmentalSurveyChoice('sometimes', 'Sometimes'),
      EnvironmentalSurveyChoice('never', 'Never'),
    ],
  ),
  EnvironmentalSurveyQuestion(
    type: 'select_one',
    name: '_53_Are_gloves_chang_tacts_and_not_reused',
    label: '53. Are gloves changed between patient contacts and not reused?',
    required: true,
    relevant:
        '\${Department_Unit} = \'medical_department\' or \${Department_Unit} = \'surgical_department\' or \${Department_Unit} = \'o_g_department\' or \${Department_Unit} = \'paediatric_department\' or \${Department_Unit} = \'department_of_family_medicine\' or \${Department_Unit} = \'other_wards_units\' or \${_43_Are_staff_observed_using_P} = \'always\' or \${_43_Are_staff_observed_using_P} = \'sometimes\'',
    choices: [
      EnvironmentalSurveyChoice('yes', 'Yes'),
      EnvironmentalSurveyChoice('no', 'No'),
    ],
  ),
  EnvironmentalSurveyQuestion(
    type: 'note',
    name: 'Environmental_Cleani_g_Waste_Management',
    label: 'Environmental Cleaning & Waste Management',
  ),
  EnvironmentalSurveyQuestion(
    type: 'select_one',
    name: '_54_Are_the_cleaning_staff_available',
    label: '54. Are the cleaning staff available?',
    required: true,
    choices: [
      EnvironmentalSurveyChoice('yes', 'Yes'),
      EnvironmentalSurveyChoice('no', 'No'),
    ],
  ),
  EnvironmentalSurveyQuestion(
    type: 'select_one',
    name: '_55_Is_the_patient_c_s_etc_visibly_clean',
    label:
        '55. Is the patient-care area (floor, bedsides, Bed tables lockers etc) visibly clean?',
    required: true,
    relevant:
        '\${Department_Unit} = \'medical_department\' or \${Department_Unit} = \'surgical_department\' or \${Department_Unit} = \'o_g_department\' or \${Department_Unit} = \'paediatric_department\' or \${Department_Unit} = \'other_wards_units\' or \${Department_Unit} = \'department_of_family_medicine\'',
    choices: [
      EnvironmentalSurveyChoice('yes', 'Yes'),
      EnvironmentalSurveyChoice('no', 'No'),
    ],
  ),
  EnvironmentalSurveyQuestion(
    type: 'select_one',
    name: '_56_Are_Beds_Spaced_least_1_meter_apart',
    label: '56. Are Beds Spaced at least 1 meter apart?',
    hint: '6',
    required: true,
    relevant:
        '\${Department_Unit} = \'medical_department\' or \${Department_Unit} = \'surgical_department\' or \${Department_Unit} = \'o_g_department\' or \${Department_Unit} = \'paediatric_department\' or \${Department_Unit} = \'department_of_family_medicine\' or \${Department_Unit} = \'other_wards_units\'',
    choices: [
      EnvironmentalSurveyChoice('yes', 'Yes'),
      EnvironmentalSurveyChoice('no', 'No'),
    ],
  ),
  EnvironmentalSurveyQuestion(
    type: 'select_one',
    name: '_57_Are_table_tops_s_etc_visibly_clean',
    label:
        '57. Are table tops (Nurses station, staff rooms etc) visibly clean?',
    required: true,
    relevant:
        '\${Department_Unit} = \'medical_department\' or \${Department_Unit} = \'surgical_department\' or \${Department_Unit} = \'o_g_department\' or \${Department_Unit} = \'paediatric_department\' or \${Department_Unit} = \'department_of_family_medicine\' or \${Department_Unit} = \'other_wards_units\' or \${Community_Medicine_Units} = \'immunization_unit\' or \${Department_Unit} = \'other_special_clinics\'',
    choices: [
      EnvironmentalSurveyChoice('yes', 'Yes'),
      EnvironmentalSurveyChoice('no', 'No'),
    ],
  ),
  EnvironmentalSurveyQuestion(
    type: 'select_one',
    name: '_49_Is_there_a_documented_clea',
    label: '58. Is there a documented cleaning schedule?',
    required: true,
    choices: [
      EnvironmentalSurveyChoice('yes', 'Yes'),
      EnvironmentalSurveyChoice('no', 'No'),
    ],
  ),
  EnvironmentalSurveyQuestion(
    type: 'select_one',
    name: '_59_Are_cleaning_sch_ocumented_and_signed',
    label: '59. Are cleaning schedules documented and signed?',
    required: true,
    relevant: '\${_49_Is_there_a_documented_clea} = \'yes\'',
    choices: [
      EnvironmentalSurveyChoice('yes', 'Yes'),
      EnvironmentalSurveyChoice('no', 'No'),
    ],
  ),
  EnvironmentalSurveyQuestion(
    type: 'select_one',
    name: '_51_Are_high_touch_surfaces_e',
    label:
        '60. Are high-touch surfaces (e.g., bed rails, door handles, computer keyboards & touch screens, light switches, telephone, IV poles, examination couch) cleaned?',
    required: true,
    relevant:
        '\${Department_Unit} = \'medical_department\' or \${Department_Unit} = \'surgical_department\' or \${Department_Unit} = \'o_g_department\' or \${Department_Unit} = \'paediatric_department\' or \${Department_Unit} = \'other_wards_units\' or \${Department_Unit} = \'department_of_family_medicine\' or \${Department_Unit} = \'ent_department\' or \${Department_Unit} = \'physiotherapy_department\' or \${Department_Unit} = \'maxillofacial_department\' or \${Department_Unit} = \'main_operating_theater\' or \${Department_Unit} = \'obstetric_theater\' or \${Department_Unit} = \'ophthalmic_complex\' or \${Department_Unit} = \'radiology_department\' or \${Department_Unit} = \'other_special_clinics\'',
    choices: [
      EnvironmentalSurveyChoice('yes', 'Yes'),
      EnvironmentalSurveyChoice('no', 'No'),
    ],
  ),
  EnvironmentalSurveyQuestion(
    type: 'select_one',
    name: '_61_Are_high_touch_s_least_once_per_shift',
    label:
        '61. Are high-touch surfaces cleaned frequently (at least once per shift)?',
    required: true,
    relevant: '\${_51_Are_high_touch_surfaces_e} = \'yes\'',
    choices: [
      EnvironmentalSurveyChoice('yes', 'Yes'),
      EnvironmentalSurveyChoice('no', 'No'),
    ],
  ),
  EnvironmentalSurveyQuestion(
    type: 'select_one',
    name: '_53_Are_appropriate_cleaning_s',
    label:
        '62. Are appropriate cleaning solution and concentration used in all surface cleanings?',
    required: true,
    choices: [
      EnvironmentalSurveyChoice('yes', 'Yes'),
      EnvironmentalSurveyChoice('no', 'No'),
    ],
  ),
  EnvironmentalSurveyQuestion(
    type: 'text',
    name: '_63_Please_what_is_t_name_of_the_solution',
    label: '63. Please what is the name of the solution?',
    required: true,
    relevant: '\${_53_Are_appropriate_cleaning_s} = \'yes\'',
  ),
  EnvironmentalSurveyQuestion(
    type: 'select_one',
    name: '_64_Are_cleaning_mat_and_stored_properly',
    label:
        '64. Are cleaning materials available (e.g., mops, buckets) and stored properly?',
    required: true,
    choices: [
      EnvironmentalSurveyChoice('yes', 'Yes, stored properly'),
      EnvironmentalSurveyChoice(
        'available_not_stored_properly',
        'Available not stored properly',
      ),
      EnvironmentalSurveyChoice('no', 'No'),
    ],
  ),
  EnvironmentalSurveyQuestion(
    type: 'select_one',
    name: '_65_Are_disinfectant_ble_at_service_point',
    label: '65. Are disinfectants available at service point?',
    required: true,
    choices: [
      EnvironmentalSurveyChoice('yes', 'Yes'),
      EnvironmentalSurveyChoice('no', 'No'),
    ],
  ),
  EnvironmentalSurveyQuestion(
    type: 'select_one',
    name: 'Are_color_coded_bins_available',
    label: '66. Are color-coded bins available at service points',
    required: true,
    choices: [
      EnvironmentalSurveyChoice('yes', 'Yes'),
      EnvironmentalSurveyChoice('no', 'No'),
    ],
  ),
  EnvironmentalSurveyQuestion(
    type: 'select_one',
    name: 'If_color_coded_bins_are_not_av',
    label:
        '67. If color coded bins are not available, are there bin lining in each of the dust bin in use?',
    required: true,
    relevant: '\${Are_color_coded_bins_available} = \'no\'',
    choices: [
      EnvironmentalSurveyChoice('yes', 'Yes'),
      EnvironmentalSurveyChoice('no', 'No'),
    ],
  ),
  EnvironmentalSurveyQuestion(
    type: 'select_one',
    name: '_68_Are_waste_bins_properly_covered',
    label: '68. Are waste bins properly covered?',
    required: true,
    relevant: '\${If_color_coded_bins_are_not_av} = \'yes\'',
    choices: [
      EnvironmentalSurveyChoice('yes', 'Yes'),
      EnvironmentalSurveyChoice('no', 'No'),
    ],
  ),
  EnvironmentalSurveyQuestion(
    type: 'select_one',
    name: '_69_Are_waste_proper_infectious_general',
    label: '69. Are waste properly segregated (sharps, infectious, general)?',
    required: true,
    relevant: '\${Are_color_coded_bins_available} = \'yes\'',
    choices: [
      EnvironmentalSurveyChoice('yes', 'Yes'),
      EnvironmentalSurveyChoice('no', 'No'),
    ],
  ),
  EnvironmentalSurveyQuestion(
    type: 'select_one',
    name: '_70_Are_color_coded_bins_used_correctly',
    label: '70. Are color-coded bins used correctly?',
    required: true,
    relevant: '\${Are_color_coded_bins_available} = \'yes\'',
    choices: [
      EnvironmentalSurveyChoice('yes', 'Yes'),
      EnvironmentalSurveyChoice('no', 'No'),
    ],
  ),
  EnvironmentalSurveyQuestion(
    type: 'note',
    name: 'Dump_Site_Incinerator',
    label: 'Dump Site/Incinerator',
    relevant:
        '\${Community_Medicine_Units} = \'incineration_room\' or \${Community_Medicine_Units} = \'dump_site\'',
  ),
  EnvironmentalSurveyQuestion(
    type: 'select_one',
    name: '_71_Is_waste_properl_ing_color_coded_bins',
    label:
        '71. Is waste properly segregated at the point of generation using color-coded bins?',
    required: true,
    relevant: '\${Community_Medicine_Units} = \'dump_site\'',
    choices: [
      EnvironmentalSurveyChoice('yes', 'Yes'),
      EnvironmentalSurveyChoice('no', 'No'),
    ],
  ),
  EnvironmentalSurveyQuestion(
    type: 'select_one',
    name: '_72_Is_medical_waste_cated_waste_trolleys',
    label:
        '72. Is medical waste transported to the dump site using covered and dedicated waste trolleys?',
    required: true,
    relevant: '\${Community_Medicine_Units} = \'dump_site\'',
    choices: [
      EnvironmentalSurveyChoice('yes', 'Yes'),
      EnvironmentalSurveyChoice('no', 'No'),
      EnvironmentalSurveyChoice('not_observed', 'Not observed'),
    ],
  ),
  EnvironmentalSurveyQuestion(
    type: 'select_one',
    name: '_73_Are_waste_handle_ring_waste_transport',
    label:
        '73. Are waste handlers wearing appropriate PPE during waste transport?',
    required: true,
    relevant:
        '\${Community_Medicine_Units} = \'dump_site\' or \${Community_Medicine_Units} = \'incineration_room\'',
    choices: [
      EnvironmentalSurveyChoice('always', 'Always'),
      EnvironmentalSurveyChoice('sometimes', 'Sometimes'),
      EnvironmentalSurveyChoice('never', 'Never'),
    ],
  ),
  EnvironmentalSurveyQuestion(
    type: 'select_one',
    name: '_74_Is_the_dump_site_authorized_personnel',
    label:
        '74. Is the dump site fenced or closed door and access restricted to authorized personnel?',
    required: true,
    relevant: '\${Community_Medicine_Units} = \'dump_site\'',
    choices: [
      EnvironmentalSurveyChoice('yes', 'Yes'),
      EnvironmentalSurveyChoice('no', 'No'),
    ],
  ),
  EnvironmentalSurveyQuestion(
    type: 'select_one',
    name: '_75_Is_general_waste_ste_at_the_dump_site',
    label:
        '75. Is general waste separated from hazardous/medical waste at the dump site?',
    required: true,
    relevant: '\${Community_Medicine_Units} = \'dump_site\'',
    choices: [
      EnvironmentalSurveyChoice('yes', 'Yes'),
      EnvironmentalSurveyChoice('no', 'No'),
    ],
  ),
  EnvironmentalSurveyQuestion(
    type: 'select_one',
    name: '_76_Are_sharps_conta_not_openly_scattered',
    label:
        '76. Are sharps containers disposed of appropriately and not openly scattered?',
    required: true,
    relevant: '\${Community_Medicine_Units} = \'dump_site\'',
    choices: [
      EnvironmentalSurveyChoice('yes', 'Yes'),
      EnvironmentalSurveyChoice('no', 'No'),
    ],
  ),
  EnvironmentalSurveyQuestion(
    type: 'select_one',
    name: '_77_Are_there_signs_ing_at_the_dump_site',
    label:
        '77. Are there signs of open burning or waste scavenging at the dump site?',
    required: true,
    relevant: '\${Community_Medicine_Units} = \'dump_site\'',
    choices: [
      EnvironmentalSurveyChoice('yes___occasionally', 'Yes – occasionally'),
      EnvironmentalSurveyChoice('yes___frequently', 'Yes – frequently'),
      EnvironmentalSurveyChoice('no', 'No'),
    ],
  ),
  EnvironmentalSurveyQuestion(
    type: 'select_one',
    name: '_78_Is_the_incinerat_ing_procedures_SOPs',
    label:
        '78. Is the incinerator functional and used according to standard operating procedures (SOPs)?',
    required: true,
    relevant: '\${Community_Medicine_Units} = \'incineration_room\'',
    choices: [
      EnvironmentalSurveyChoice('yes', 'Yes'),
      EnvironmentalSurveyChoice('no', 'No'),
      EnvironmentalSurveyChoice('irregularly_used', 'Irregularly used'),
    ],
  ),
  EnvironmentalSurveyQuestion(
    type: 'select_one',
    name: '_79_Is_the_incinerat_m_waste_accumulation',
    label:
        '79. Is the incinerator area clean and free from waste accumulation?',
    required: true,
    relevant: '\${Community_Medicine_Units} = \'incineration_room\'',
    choices: [
      EnvironmentalSurveyChoice('yes', 'Yes'),
      EnvironmentalSurveyChoice('no', 'No'),
    ],
  ),
  EnvironmentalSurveyQuestion(
    type: 'select_one',
    name: 'Are_procedure_in_pla_from_the_incinerator',
    label:
        'Are procedure in place to recycle and dispose of residues from the incinerator?',
    required: true,
    relevant: '\${Community_Medicine_Units} = \'incineration_room\'',
    choices: [
      EnvironmentalSurveyChoice('yes', 'Yes'),
      EnvironmentalSurveyChoice('no', 'No'),
    ],
  ),
  EnvironmentalSurveyQuestion(
    type: 'select_one',
    name: '_80_Is_there_any_vis_m_on_the_incinerator',
    label:
        '80. Is there any visible emission control or chimney system on the incinerator?',
    required: true,
    relevant: '\${Community_Medicine_Units} = \'incineration_room\'',
    choices: [
      EnvironmentalSurveyChoice('yes', 'Yes'),
      EnvironmentalSurveyChoice('no', 'No'),
    ],
  ),
  EnvironmentalSurveyQuestion(
    type: 'select_one',
    name: '_81_Are_there_signs_ump_incinerator_site',
    label:
        '81. Are there signs of vector breeding (e.g., flies, rodents) around the dump/incinerator site?',
    required: true,
    relevant: '\${Community_Medicine_Units} = \'dump_site\'',
    choices: [
      EnvironmentalSurveyChoice('yes___severe', 'Yes – severe'),
      EnvironmentalSurveyChoice('yes___mild', 'Yes – mild'),
      EnvironmentalSurveyChoice('no', 'No'),
    ],
  ),
  EnvironmentalSurveyQuestion(
    type: 'select_one',
    name: '_82_Is_spill_contain_vailable_at_the_site',
    label:
        '82. Is spill containment material (e.g., absorbent, bleach) available at the site?',
    required: true,
    relevant: '\${Community_Medicine_Units} = \'dump_site\'',
    choices: [
      EnvironmentalSurveyChoice('yes', 'Yes'),
      EnvironmentalSurveyChoice('no', 'No'),
    ],
  ),
  EnvironmentalSurveyQuestion(
    type: 'select_one',
    name: '_83_Incinerator_oper_ion_manual_available',
    label: '83. Incinerator operation manual available?',
    required: true,
    relevant: '\${Community_Medicine_Units} = \'incineration_room\'',
    choices: [
      EnvironmentalSurveyChoice('yes', 'Yes'),
      EnvironmentalSurveyChoice('no', 'No'),
    ],
  ),
  EnvironmentalSurveyQuestion(
    type: 'select_one',
    name: '_84_Incinerator_reco_y_Monthly_Available',
    label: '84. Incinerator record (Daily/Weekly/Monthly) Available?',
    required: true,
    relevant: '\${Community_Medicine_Units} = \'incineration_room\'',
    choices: [
      EnvironmentalSurveyChoice('yes', 'Yes'),
      EnvironmentalSurveyChoice('no', 'No'),
    ],
  ),
  EnvironmentalSurveyQuestion(
    type: 'select_one',
    name: '_85_Is_there_a_Stand_procedure_available',
    label: '85. Is there a Standard operating procedure available?',
    hint: 'it must be sighted by the data collector',
    required: true,
    relevant:
        '\${Community_Medicine_Units} = \'incineration_room\' or \${Community_Medicine_Units} = \'dump_site\'',
    choices: [
      EnvironmentalSurveyChoice('yes', 'Yes'),
      EnvironmentalSurveyChoice('no', 'No'),
    ],
  ),
  EnvironmentalSurveyQuestion(
    type: 'select_one',
    name: '_86_Are_there_visibl_ning_signs_available',
    label: '86. Are there visible Biohazard warning signs available?',
    required: true,
    relevant:
        '\${Community_Medicine_Units} = \'incineration_room\' or \${Community_Medicine_Units} = \'dump_site\'',
    choices: [
      EnvironmentalSurveyChoice('yes', 'Yes'),
      EnvironmentalSurveyChoice('no', 'No'),
    ],
  ),
  EnvironmentalSurveyQuestion(
    type: 'select_one',
    name: '_87_Is_the_storage_Area_Easily_Cleaned',
    label: '87. Is the storage Area Easily Cleaned?',
    required: true,
    relevant: '\${Community_Medicine_Units} = \'dump_site\'',
    choices: [
      EnvironmentalSurveyChoice('yes', 'Yes'),
      EnvironmentalSurveyChoice('no', 'No'),
    ],
  ),
  EnvironmentalSurveyQuestion(
    type: 'select_one',
    name: '_88_Are_the_waste_weight_upon_reciept',
    label: '88. Are the waste weight upon reciept?',
    required: true,
    relevant: '\${Community_Medicine_Units} = \'dump_site\'',
    choices: [
      EnvironmentalSurveyChoice('yes', 'Yes'),
      EnvironmentalSurveyChoice('no', 'No'),
    ],
  ),
  EnvironmentalSurveyQuestion(
    type: 'select_one',
    name: '_89_Have_all_staff_b_B_polio_and_tetanus',
    label:
        '89. Have all staff been immunized against hepatitis A, B polio and tetanus?',
    required: true,
    relevant:
        '\${Community_Medicine_Units} = \'incineration_room\' or \${Community_Medicine_Units} = \'dump_site\'',
    choices: [
      EnvironmentalSurveyChoice('yes', 'Yes'),
      EnvironmentalSurveyChoice('no', 'No'),
    ],
  ),
  EnvironmentalSurveyQuestion(
    type: 'select_one',
    name: 'Are_sharps_containers_availabl',
    label: '90. Are sharps containers available and properly labeled?',
    required: true,
    relevant:
        '\${Department_Unit} = \'medical_department\' or \${Department_Unit} = \'surgical_department\' or \${Department_Unit} = \'o_g_department\' or \${Department_Unit} = \'paediatric_department\' or \${Department_Unit} = \'other_wards_units\' or \${Department_Unit} = \'department_of_family_medicine\' or \${Department_Unit} = \'ent_department\' or \${Department_Unit} = \'maxillofacial_department\' or \${Department_Unit} = \'main_operating_theater\' or \${Department_Unit} = \'obstetric_theater\' or \${Department_Unit} = \'ophthalmic_complex\' or \${Haematology_Units} = \'bleeding_room\' or \${Department_Unit} = \'medical_microbiology_departmen\' or \${Department_Unit} = \'other_special_clinics\' or \${Histopathology_Units} = \'mortuary\'',
    choices: [
      EnvironmentalSurveyChoice('yes', 'Yes'),
      EnvironmentalSurveyChoice('no', 'No'),
    ],
  ),
  EnvironmentalSurveyQuestion(
    type: 'select_one',
    name: '_91_Are_sharp_contai_y_and_not_overfilled',
    label: '91. Are sharp containers emptied regularly and not overfilled?',
    required: true,
    relevant: '\${Are_sharps_containers_availabl} = \'yes\'',
    choices: [
      EnvironmentalSurveyChoice('yes', 'Yes'),
      EnvironmentalSurveyChoice('no', 'No'),
    ],
  ),
  EnvironmentalSurveyQuestion(
    type: 'select_one',
    name: '_92_Are_waste_bins_emptied_regularly',
    label: '92. Are waste bins emptied regularly?',
    required: true,
    choices: [
      EnvironmentalSurveyChoice('yes', 'Yes'),
      EnvironmentalSurveyChoice('no', 'No'),
    ],
  ),
  EnvironmentalSurveyQuestion(
    type: 'select_one',
    name: '_93_Are_spills_bloo_priate_disinfectants',
    label:
        '93. Are spills (blood/body fluids) promptly cleaned using appropriate disinfectants?',
    required: true,
    relevant:
        '\${Department_Unit} = \'medical_department\' or \${Department_Unit} = \'surgical_department\' or \${Department_Unit} = \'o_g_department\' or \${Department_Unit} = \'paediatric_department\' or \${Department_Unit} = \'department_of_family_medicine\' or \${Department_Unit} = \'other_wards_units\'',
    choices: [
      EnvironmentalSurveyChoice('yes', 'Yes'),
      EnvironmentalSurveyChoice('no', 'No'),
    ],
  ),
  EnvironmentalSurveyQuestion(
    type: 'select_one',
    name: '_94_Are_dental_ENT_s_sed_of_appropriately',
    label:
        '94. Are dental/ENT suction and fluid waste disposed of appropriately?',
    required: true,
    relevant:
        '\${Department_Unit} = \'ent_department\' or \${Department_Unit} = \'maxillofacial_department\'',
    choices: [
      EnvironmentalSurveyChoice('yes', 'Yes'),
      EnvironmentalSurveyChoice('no', 'No'),
    ],
  ),
  EnvironmentalSurveyQuestion(
    type: 'note',
    name: 'Linen_and_Medical_Equipment_Management',
    label: 'Linen and Medical Equipment Management',
    relevant:
        '\${Department_Unit} = \'medical_department\' or \${Department_Unit} = \'surgical_department\' or \${Department_Unit} = \'o_g_department\' or \${Department_Unit} = \'paediatric_department\' or \${Department_Unit} = \'other_wards_units\' or \${Department_Unit} = \'department_of_family_medicine\'',
  ),
  EnvironmentalSurveyQuestion(
    type: 'select_one',
    name: '_95_Are_laundry_bags_ble_on_the_ward_unit',
    label: '95. Are laundry bags available on the ward/unit?',
    required: true,
    relevant:
        '\${Department_Unit} = \'medical_department\' or \${Department_Unit} = \'surgical_department\' or \${Department_Unit} = \'o_g_department\' or \${Department_Unit} = \'paediatric_department\' or \${Department_Unit} = \'other_wards_units\' or \${Department_Unit} = \'department_of_family_medicine\'',
    choices: [
      EnvironmentalSurveyChoice('yes', 'Yes'),
      EnvironmentalSurveyChoice('no', 'No'),
    ],
  ),
  EnvironmentalSurveyQuestion(
    type: 'select_one',
    name: '_96_Are_clean_linens_ocation_on_the_ward_',
    label: '96. Are clean linens stored in a secured location on the ward ?',
    required: true,
    relevant:
        '\${Department_Unit} = \'medical_department\' or \${Department_Unit} = \'surgical_department\' or \${Department_Unit} = \'o_g_department\' or \${Department_Unit} = \'paediatric_department\' or \${Department_Unit} = \'other_wards_units\' or \${Department_Unit} = \'department_of_family_medicine\'',
    choices: [
      EnvironmentalSurveyChoice('yes', 'Yes'),
      EnvironmentalSurveyChoice('no', 'No'),
    ],
  ),
  EnvironmentalSurveyQuestion(
    type: 'select_one',
    name: '_97_Are_soiled_linen_ked_in_a_laundry_bag',
    label:
        '97. Are soiled linens handled in a designated area on the ward and stored separately and neatly packed in a laundry bag?',
    required: true,
    relevant:
        '\${Department_Unit} = \'medical_department\' or \${Department_Unit} = \'surgical_department\' or \${Department_Unit} = \'o_g_department\' or \${Department_Unit} = \'paediatric_department\' or \${Department_Unit} = \'other_wards_units\' or \${Department_Unit} = \'department_of_family_medicine\'',
    choices: [
      EnvironmentalSurveyChoice('yes', 'Yes'),
      EnvironmentalSurveyChoice('no', 'No'),
    ],
  ),
  EnvironmentalSurveyQuestion(
    type: 'select_one',
    name: '_98_Are_PPE_used_whe_ndling_soiled_linens',
    label: '98. Are PPE used when handling soiled linens?',
    required: true,
    relevant:
        '\${Department_Unit} = \'medical_department\' or \${Department_Unit} = \'surgical_department\' or \${Department_Unit} = \'o_g_department\' or \${Department_Unit} = \'paediatric_department\' or \${Department_Unit} = \'other_wards_units\' or \${Department_Unit} = \'department_of_family_medicine\'',
    choices: [
      EnvironmentalSurveyChoice('yes', 'Always'),
      EnvironmentalSurveyChoice('no', 'Smoetimes'),
      EnvironmentalSurveyChoice('no_1', 'No'),
    ],
  ),
  EnvironmentalSurveyQuestion(
    type: 'select_one',
    name: '_99_Are_soiled_linen_proof_labeled_bags',
    label: '99. Are soiled linens collected in leak-proof, labeled bags?',
    required: true,
    relevant: '\${Department_Unit} = \'laundry_unit\'',
    choices: [
      EnvironmentalSurveyChoice('yes', 'Yes'),
      EnvironmentalSurveyChoice('no', 'No'),
    ],
  ),
  EnvironmentalSurveyQuestion(
    type: 'select_one',
    name: '_99_Are_linen_bags_c_red_for_infectious',
    label:
        '99. Are linen bags color-coded according to hospital policy (e.g., red for infectious)?',
    required: true,
    relevant: '\${Department_Unit} = \'laundry_unit\'',
    choices: [
      EnvironmentalSurveyChoice('yes', 'Yes'),
      EnvironmentalSurveyChoice('no', 'No'),
    ],
  ),
  EnvironmentalSurveyQuestion(
    type: 'select_one',
    name: '_100_Are_bags_secure_d_and_not_overfilled',
    label: '100. Are bags securely tied or trolley covered and not overfilled?',
    required: true,
    relevant: '\${Department_Unit} = \'laundry_unit\'',
    choices: [
      EnvironmentalSurveyChoice('yes', 'Yes'),
      EnvironmentalSurveyChoice('no', 'No'),
    ],
  ),
  EnvironmentalSurveyQuestion(
    type: 'select_one',
    name: '_101_Are_designated_ansport_soiled_linen',
    label: '101. Are designated trolleys used to transport soiled linen?',
    required: true,
    relevant: '\${Department_Unit} = \'laundry_unit\'',
    choices: [
      EnvironmentalSurveyChoice('yes', 'Yes'),
      EnvironmentalSurveyChoice('no', 'No'),
    ],
  ),
  EnvironmentalSurveyQuestion(
    type: 'select_one',
    name: '_102_Is_sorting_of_s_signated_dirty_area',
    label: '102. Is sorting of soiled linen done in a designated “dirty area”?',
    required: true,
    relevant: '\${Department_Unit} = \'laundry_unit\'',
    choices: [
      EnvironmentalSurveyChoice('yes', 'Yes'),
      EnvironmentalSurveyChoice('no', 'No'),
    ],
  ),
  EnvironmentalSurveyQuestion(
    type: 'select_one',
    name: '_103_Are_staff_weari_es_apron_face_mask',
    label:
        '103. Are staff wearing appropriate PPE while handling soiled linen (gloves, apron, face mask)?',
    required: true,
    relevant: '\${Department_Unit} = \'laundry_unit\'',
    choices: [
      EnvironmentalSurveyChoice('yes', 'Yes'),
      EnvironmentalSurveyChoice('no', 'No'),
    ],
  ),
  EnvironmentalSurveyQuestion(
    type: 'select_one',
    name: '_104_Are_transport_t_ected_after_each_use',
    label:
        '104. Are transport trolleys cleaned and disinfected after each use?',
    required: true,
    relevant: '\${Department_Unit} = \'laundry_unit\'',
    choices: [
      EnvironmentalSurveyChoice('yes', 'Yes'),
      EnvironmentalSurveyChoice('no', 'No'),
    ],
  ),
  EnvironmentalSurveyQuestion(
    type: 'select_one',
    name: '_105_Is_visible_orga_moved_before_washing',
    label:
        '105. Is visible organic matter (e.g., feces, blood) removed before washing?',
    required: true,
    relevant: '\${Department_Unit} = \'laundry_unit\'',
    choices: [
      EnvironmentalSurveyChoice('yes', 'Yes'),
      EnvironmentalSurveyChoice('no', 'No'),
    ],
  ),
  EnvironmentalSurveyQuestion(
    type: 'select_one',
    name: '_106_Are_clean_and_d_cated_in_the_laundry',
    label: '106. Are clean and dirty zones clearly demarcated in the laundry?',
    required: true,
    relevant: '\${Department_Unit} = \'laundry_unit\'',
    choices: [
      EnvironmentalSurveyChoice('yes', 'Yes'),
      EnvironmentalSurveyChoice('no', 'No'),
    ],
  ),
  EnvironmentalSurveyQuestion(
    type: 'select_one',
    name: '_107_Is_there_a_one_cross_contamination',
    label:
        '107. Is there a one-way workflow from dirty to clean area to prevent cross-contamination?',
    required: true,
    relevant: '\${Department_Unit} = \'laundry_unit\'',
    choices: [
      EnvironmentalSurveyChoice('yes', 'Yes'),
      EnvironmentalSurveyChoice('no', 'No'),
    ],
  ),
  EnvironmentalSurveyQuestion(
    type: 'select_one',
    name: '_108_Are_reusable_eq_ethoscopes_BP_cuffs',
    label:
        '108. Are reusable equipment cleaned/disinfected between uses (e.g., stethoscopes, BP cuffs)?',
    required: true,
    relevant:
        '\${Department_Unit} = \'medical_department\' or \${Department_Unit} = \'surgical_department\' or \${Department_Unit} = \'o_g_department\' or \${Department_Unit} = \'paediatric_department\' or \${Department_Unit} = \'other_wards_units\' or \${Department_Unit} = \'department_of_family_medicine\'',
    choices: [
      EnvironmentalSurveyChoice('yes', 'Yes'),
      EnvironmentalSurveyChoice('no', 'No'),
    ],
  ),
  EnvironmentalSurveyQuestion(
    type: 'select_one',
    name: '_109_Are_oxygen_humi_ried_when_not_in_use',
    label:
        '109. Are oxygen humidifiers emptied and suction machines, cleaned, disinfected and dried when not in use?',
    required: true,
    relevant:
        '\${Department_Unit} = \'medical_department\' or \${Department_Unit} = \'surgical_department\' or \${Department_Unit} = \'o_g_department\' or \${Department_Unit} = \'paediatric_department\' or \${Department_Unit} = \'department_of_family_medicine\' or \${Department_Unit} = \'other_wards_units\'',
    choices: [
      EnvironmentalSurveyChoice('yes', 'Yes'),
      EnvironmentalSurveyChoice('no', 'No'),
    ],
  ),
  EnvironmentalSurveyQuestion(
    type: 'select_one',
    name: '_110_Are_sterilized_ents_stored_properly',
    label: '110. Are sterilized instruments stored properly?',
    required: true,
    relevant:
        '\${Department_Unit} = \'medical_department\' or \${Department_Unit} = \'surgical_department\' or \${Department_Unit} = \'o_g_department\' or \${Department_Unit} = \'paediatric_department\' or \${Department_Unit} = \'other_wards_units\' or \${Department_Unit} = \'department_of_family_medicine\'',
    choices: [
      EnvironmentalSurveyChoice('yes', 'Yes'),
      EnvironmentalSurveyChoice('not_available', 'Not Available'),
      EnvironmentalSurveyChoice('no', 'No'),
    ],
  ),
  EnvironmentalSurveyQuestion(
    type: 'select_one',
    name: '_112_Is_there_docume_ipment_cleaning_logs',
    label: '112. Is there documentation of equipment cleaning logs?',
    required: true,
    relevant:
        '\${Department_Unit} = \'medical_department\' or \${Department_Unit} = \'surgical_department\' or \${Department_Unit} = \'o_g_department\' or \${Department_Unit} = \'paediatric_department\' or \${Department_Unit} = \'other_wards_units\' or \${Department_Unit} = \'department_of_family_medicine\'',
    choices: [
      EnvironmentalSurveyChoice('yes', 'Yes'),
      EnvironmentalSurveyChoice('no', 'No'),
    ],
  ),
  EnvironmentalSurveyQuestion(
    type: 'select_one',
    name: '_113_Are_trolley_tops_visibly_clean',
    label: '113. Are trolley tops visibly clean?',
    required: true,
    relevant:
        '\${Department_Unit} = \'medical_department\' or \${Department_Unit} = \'surgical_department\' or \${Department_Unit} = \'o_g_department\' or \${Department_Unit} = \'department_of_family_medicine\' or \${Department_Unit} = \'other_wards_units\' or \${Paediatric_Wards_Clinics} = \'pediatric_medical_ward\'',
    choices: [
      EnvironmentalSurveyChoice('yes', 'Yes'),
      EnvironmentalSurveyChoice('no', 'No'),
    ],
  ),
  EnvironmentalSurveyQuestion(
    type: 'select_one',
    name: '_114_Are_Ward_refrigerator_cleaned',
    label: '114. Are Ward refrigerator cleaned?',
    required: true,
    relevant:
        '\${Department_Unit} = \'medical_department\' or \${Department_Unit} = \'surgical_department\' or \${Department_Unit} = \'o_g_department\' or \${Department_Unit} = \'paediatric_department\' or \${Department_Unit} = \'department_of_family_medicine\' or \${Department_Unit} = \'other_wards_units\'',
    choices: [
      EnvironmentalSurveyChoice('yes', 'Yes'),
      EnvironmentalSurveyChoice('not_applicable', 'Not Applicable'),
      EnvironmentalSurveyChoice('no', 'No'),
    ],
  ),
  EnvironmentalSurveyQuestion(
    type: 'select_one',
    name: '_115_Are_machines_cl_maintained_regularly',
    label: '115. Are machines cleaned and maintained regularly?',
    required: true,
    relevant: '\${Department_Unit} = \'laundry_unit\'',
    choices: [
      EnvironmentalSurveyChoice('yes', 'Yes'),
      EnvironmentalSurveyChoice('no', 'No'),
    ],
  ),
  EnvironmentalSurveyQuestion(
    type: 'select_one',
    name: '_116_Linen_dried_in_ust_free_environment',
    label: '116. Linen dried in a clean, dust-free environment?',
    required: true,
    relevant: '\${Department_Unit} = \'laundry_unit\'',
    choices: [
      EnvironmentalSurveyChoice('yes', 'Yes'),
      EnvironmentalSurveyChoice('no', 'No'),
    ],
  ),
  EnvironmentalSurveyQuestion(
    type: 'select_one',
    name: '_117_Are_clean_linen_area_off_the_floor',
    label:
        '117. Are clean linens stored in a dedicated clean area, off the floor?',
    required: true,
    relevant: '\${Department_Unit} = \'laundry_unit\'',
    choices: [
      EnvironmentalSurveyChoice('yes', 'Yes'),
      EnvironmentalSurveyChoice('no', 'No'),
    ],
  ),
  EnvironmentalSurveyQuestion(
    type: 'select_one',
    name: '_118_Is_transportati_an_covered_trolleys',
    label:
        '118. Is transportation of clean linen done in clean, covered trolleys?',
    required: true,
    relevant: '\${Department_Unit} = \'laundry_unit\'',
    choices: [
      EnvironmentalSurveyChoice('yes', 'Yes'),
      EnvironmentalSurveyChoice('no', 'No'),
    ],
  ),
  EnvironmentalSurveyQuestion(
    type: 'select_one',
    name: '_119_Are_hand_hygien_in_the_laundry_area',
    label: '119. Are hand hygiene facilities available in the laundry area?',
    required: true,
    relevant: '\${Department_Unit} = \'laundry_unit\'',
    choices: [
      EnvironmentalSurveyChoice('yes', 'Yes'),
      EnvironmentalSurveyChoice('no', 'No'),
    ],
  ),
  EnvironmentalSurveyQuestion(
    type: 'select_one',
    name: '_120_Are_staff_obser_inen_or_removing_PPE',
    label:
        '120. Are staff observed practicing hand hygiene after handling soiled linen or removing PPE?',
    required: true,
    relevant: '\${Department_Unit} = \'laundry_unit\'',
    choices: [
      EnvironmentalSurveyChoice('yes', 'Yes'),
      EnvironmentalSurveyChoice('no', 'No'),
    ],
  ),
  EnvironmentalSurveyQuestion(
    type: 'select_one',
    name: '_121_Are_waste_bins_for_soiled_materials',
    label:
        '121. Are waste bins available and color-coded for soiled materials?',
    required: true,
    relevant: '\${Department_Unit} = \'laundry_unit\'',
    choices: [
      EnvironmentalSurveyChoice('yes', 'Yes'),
      EnvironmentalSurveyChoice('no', 'No'),
    ],
  ),
  EnvironmentalSurveyQuestion(
    type: 'select_one',
    name: '_122_Are_linen_bags_ectly_after_emptying',
    label: '122. Are linen bags disposed of correctly after emptying?',
    required: true,
    relevant: '\${Department_Unit} = \'laundry_unit\'',
    choices: [
      EnvironmentalSurveyChoice('yes', 'Yes'),
      EnvironmentalSurveyChoice('no', 'No'),
    ],
  ),
  EnvironmentalSurveyQuestion(
    type: 'select_one',
    name: '_123_Are_spill_kits_in_the_laundry_area',
    label: '123. Are spill kits readily available in the laundry area?',
    required: true,
    relevant: '\${Department_Unit} = \'laundry_unit\'',
    choices: [
      EnvironmentalSurveyChoice('yes', 'Yes'),
      EnvironmentalSurveyChoice('no', 'No'),
    ],
  ),
  EnvironmentalSurveyQuestion(
    type: 'note',
    name: 'Triage_Protocol',
    label: 'Triage Protocol',
    relevant: '\${Department_Unit} = \'department_of_family_medicine\'',
  ),
  EnvironmentalSurveyQuestion(
    type: 'select_one',
    name: '_124_Is_there_a_clea_eneral_waiting_areas',
    label:
        '124. Is there a clearly designated triage area separate from general waiting areas?',
    required: true,
    relevant: '\${Department_Unit} = \'department_of_family_medicine\'',
    choices: [
      EnvironmentalSurveyChoice('yes', 'Yes'),
      EnvironmentalSurveyChoice('no', 'No'),
    ],
  ),
  EnvironmentalSurveyQuestion(
    type: 'select_one',
    name: 'Is_there_a_dedicated_staff_mem',
    label:
        '125. Is there a dedicated staff member assigned to triage during all operational hours?',
    required: true,
    relevant: '\${Department_Unit} = \'department_of_family_medicine\'',
    choices: [
      EnvironmentalSurveyChoice('yes', 'Yes'),
      EnvironmentalSurveyChoice('no', 'No'),
    ],
  ),
  EnvironmentalSurveyQuestion(
    type: 'select_one',
    name: '_126_Are_patients_sc_ver_rash_at_triage',
    label:
        '126. Are patients screened for infectious symptoms (e.g., cough, fever, rash) at triage?',
    required: true,
    relevant: '\${Department_Unit} = \'department_of_family_medicine\'',
    choices: [
      EnvironmentalSurveyChoice('yes', 'Yes'),
      EnvironmentalSurveyChoice('no', 'No'),
    ],
  ),
  EnvironmentalSurveyQuestion(
    type: 'select_one',
    name: '_127_Are_suspected_i_nd_isolated_promptly',
    label:
        '127. Are suspected infectious patients prioritized and isolated promptly?',
    required: true,
    relevant: '\${Department_Unit} = \'department_of_family_medicine\'',
    choices: [
      EnvironmentalSurveyChoice('yes', 'Yes'),
      EnvironmentalSurveyChoice('no', 'No'),
    ],
  ),
  EnvironmentalSurveyQuestion(
    type: 'select_one',
    name: '_128_Is_PPE_used_app_tely_by_triage_staff',
    label: ' 128. Is PPE used appropriately by triage staff?',
    required: true,
    relevant:
        '\${Department_Unit} = \'department_of_family_medicine\' or \${Is_there_a_dedicated_staff_mem} = \'yes\'',
    choices: [
      EnvironmentalSurveyChoice('yes', 'Yes'),
      EnvironmentalSurveyChoice('no', 'No'),
    ],
  ),
  EnvironmentalSurveyQuestion(
    type: 'select_one',
    name: '_129_Is_there_a_dedi_available_for_triage',
    label:
        '129. Is there a dedicated medical equipment (e.g. BP cuff, thermometer etc) available for triage?',
    required: true,
    relevant: '\${Department_Unit} = \'department_of_family_medicine\'',
    choices: [
      EnvironmentalSurveyChoice('yes', 'Yes'),
      EnvironmentalSurveyChoice('no', 'No'),
    ],
  ),
  EnvironmentalSurveyQuestion(
    type: 'note',
    name: 'Central_Sterile_Supply_Unit',
    label: 'Central Sterile Supply Unit',
    relevant: '\${MOT_Units} = \'central_sterile_supply_unit\'',
  ),
  EnvironmentalSurveyQuestion(
    type: 'select_one',
    name: '_130_Are_the_CSSD_ar_n_and_sterile_zones',
    label:
        '130. Are the CSSD areas clearly zoned into dirty, clean, and sterile zones?',
    required: true,
    relevant: '\${MOT_Units} = \'central_sterile_supply_unit\'',
    choices: [
      EnvironmentalSurveyChoice('yes', 'Yes'),
      EnvironmentalSurveyChoice('no', 'No'),
    ],
  ),
  EnvironmentalSurveyQuestion(
    type: 'select_one',
    name: '_131_Is_there_a_unid_irty_to_sterile_area',
    label:
        '131. Is there a unidirectional workflow from dirty to sterile area?',
    required: true,
    relevant: '\${MOT_Units} = \'central_sterile_supply_unit\'',
    choices: [
      EnvironmentalSurveyChoice('yes', 'Yes'),
      EnvironmentalSurveyChoice('no', 'No'),
    ],
  ),
  EnvironmentalSurveyQuestion(
    type: 'select_one',
    name: '_132_Is_manual_clean_er_to_avoid_splashes',
    label:
        '132. Is manual cleaning done with appropriate brushes under water to avoid splashes?',
    required: true,
    relevant: '\${MOT_Units} = \'central_sterile_supply_unit\'',
    choices: [
      EnvironmentalSurveyChoice('yes', 'Yes'),
      EnvironmentalSurveyChoice('no', 'No'),
    ],
  ),
  EnvironmentalSurveyQuestion(
    type: 'select_one',
    name: '_133_Are_staff_weari_ring_decontamination',
    label:
        '133. Are staff wearing full PPE (gloves, apron, mask, goggles) during decontamination?',
    required: true,
    relevant: '\${MOT_Units} = \'central_sterile_supply_unit\'',
    choices: [
      EnvironmentalSurveyChoice('yes', 'Yes'),
      EnvironmentalSurveyChoice('no', 'No'),
    ],
  ),
  EnvironmentalSurveyQuestion(
    type: 'select_one',
    name: '_134_Are_sterilizers_eventive_maintenance',
    label:
        '134. Are sterilizers (e.g., autoclaves) functioning properly with routine preventive maintenance?',
    required: true,
    relevant: '\${MOT_Units} = \'central_sterile_supply_unit\'',
    choices: [
      EnvironmentalSurveyChoice('yes', 'Yes'),
      EnvironmentalSurveyChoice('no', 'No'),
    ],
  ),
  EnvironmentalSurveyQuestion(
    type: 'select_one',
    name: '_135_Are_biological_o_monitor_each_cycle',
    label:
        '135. Are biological or chemical indicators used to monitor each cycle?',
    required: true,
    relevant: '\${MOT_Units} = \'central_sterile_supply_unit\'',
    choices: [
      EnvironmentalSurveyChoice('yes', 'Yes'),
      EnvironmentalSurveyChoice('no', 'No'),
    ],
  ),
  EnvironmentalSurveyQuestion(
    type: 'select_one',
    name: '_136_Are_indicator_s_ide_instrument_packs',
    label: '136. Are indicator strips placed inside instrument packs?',
    required: true,
    relevant: '\${MOT_Units} = \'central_sterile_supply_unit\'',
    choices: [
      EnvironmentalSurveyChoice('yes', 'Yes'),
      EnvironmentalSurveyChoice('no', 'No'),
    ],
  ),
  EnvironmentalSurveyQuestion(
    type: 'select_one',
    name: '_137_Are_parameters_sterilization_cycle',
    label:
        '137. Are parameters (time, temperature, pressure) recorded for each sterilization cycle?',
    required: true,
    relevant: '\${MOT_Units} = \'central_sterile_supply_unit\'',
    choices: [
      EnvironmentalSurveyChoice('yes', 'Yes'),
      EnvironmentalSurveyChoice('no', 'No'),
    ],
  ),
  EnvironmentalSurveyQuestion(
    type: 'select_one',
    name: '_138_Are_sterile_pac_ust_free_environment',
    label:
        '138. Are sterile packs stored in a clean, dry, dust-free environment?',
    required: true,
    relevant: '\${MOT_Units} = \'central_sterile_supply_unit\'',
    choices: [
      EnvironmentalSurveyChoice('yes', 'Yes'),
      EnvironmentalSurveyChoice('no', 'No'),
    ],
  ),
  EnvironmentalSurveyQuestion(
    type: 'select_one',
    name: '_139_Are_sterile_ite_sterilization_dates',
    label: '139. Are sterile items labeled with expiry or sterilization dates?',
    required: true,
    relevant: '\${MOT_Units} = \'central_sterile_supply_unit\'',
    choices: [
      EnvironmentalSurveyChoice('yes', 'Yes'),
      EnvironmentalSurveyChoice('no', 'No'),
    ],
  ),
  EnvironmentalSurveyQuestion(
    type: 'select_one',
    name: '_140_Are_damaged_or_culation_immediately',
    label:
        '140. Are damaged or expired packs removed from circulation immediately?',
    required: true,
    relevant: '\${MOT_Units} = \'central_sterile_supply_unit\'',
    choices: [
      EnvironmentalSurveyChoice('yes', 'Yes'),
      EnvironmentalSurveyChoice('no', 'No'),
    ],
  ),
  EnvironmentalSurveyQuestion(
    type: 'select_one',
    name: '_141_Are_sterilizati_d_reviewed_regularly',
    label: '141. Are sterilization records maintained and reviewed regularly?',
    required: true,
    relevant: '\${MOT_Units} = \'central_sterile_supply_unit\'',
    choices: [
      EnvironmentalSurveyChoice('yes', 'Yes'),
      EnvironmentalSurveyChoice('no', 'No'),
      EnvironmentalSurveyChoice('irregularly', 'Irregularly'),
    ],
  ),
  EnvironmentalSurveyQuestion(
    type: 'select_one',
    name: '_142_Is_a_tracking_s_sterilization_to_use',
    label:
        '142. Is a tracking system in place to trace instruments from sterilization to use?',
    required: true,
    relevant: '\${MOT_Units} = \'central_sterile_supply_unit\'',
    choices: [
      EnvironmentalSurveyChoice('yes', 'Yes'),
      EnvironmentalSurveyChoice('manual_only', 'Manual only'),
      EnvironmentalSurveyChoice('no', 'No'),
    ],
  ),
  EnvironmentalSurveyQuestion(
    type: 'select_one',
    name: '_143_Are_internal_au_conducted_routinely',
    label: '143. Are internal audits or quality checks conducted routinely?',
    required: true,
    relevant: '\${MOT_Units} = \'central_sterile_supply_unit\'',
    choices: [
      EnvironmentalSurveyChoice('yes', 'Yes'),
      EnvironmentalSurveyChoice('occasionally', 'Occasionally'),
      EnvironmentalSurveyChoice('no', 'No'),
    ],
  ),
  EnvironmentalSurveyQuestion(
    type: 'note',
    name: 'Incidence_of_Needle_Stick_Injuries',
    label: 'Incidence of Needle Stick Injuries',
  ),
  EnvironmentalSurveyQuestion(
    type: 'select_one',
    name: '_116_Is_there_any_incidence_of',
    label: '144. Is there any incidence of needle stick injury that occured?',
    choices: [
      EnvironmentalSurveyChoice('yes', 'Yes'),
      EnvironmentalSurveyChoice('no', 'No'),
      EnvironmentalSurveyChoice('unknown', 'Unknown'),
    ],
  ),
  EnvironmentalSurveyQuestion(
    type: 'text',
    name: '_145_If_yes_what_ki_at_caused_the_injury',
    label: '145. If yes, what kind of instrument that caused the injury?',
    required: true,
    relevant: '\${_116_Is_there_any_incidence_of} = \'yes\'',
  ),
  EnvironmentalSurveyQuestion(
    type: 'select_one',
    name: '_146_Was_the_incidence_properly_reported',
    label: '146. Was the incidence properly reported?',
    required: true,
    relevant: '\${_116_Is_there_any_incidence_of} = \'yes\'',
    choices: [
      EnvironmentalSurveyChoice('yes', 'Yes'),
      EnvironmentalSurveyChoice('no', 'No'),
    ],
  ),
  EnvironmentalSurveyQuestion(
    type: 'select_one',
    name: '_147_Did_the_affecte_exposure_prophylaxis',
    label:
        '147. Did the affected staff recieved proper post exposure prophylaxis?',
    required: true,
    relevant: '\${_116_Is_there_any_incidence_of} = \'yes\'',
    choices: [
      EnvironmentalSurveyChoice('yes', 'Yes'),
      EnvironmentalSurveyChoice('no', 'No'),
      EnvironmentalSurveyChoice('unknown', 'Unknown'),
    ],
  ),
  EnvironmentalSurveyQuestion(
    type: 'select_one',
    name: '_120_Is_the_affected_staff_imm',
    label:
        '148. Is the affected staff immunized against hepatitis A, B and tetanus?',
    required: true,
    relevant: '\${_116_Is_there_any_incidence_of} = \'yes\'',
    choices: [
      EnvironmentalSurveyChoice('yes', 'Yes'),
      EnvironmentalSurveyChoice('no', 'No'),
      EnvironmentalSurveyChoice('unknown', 'Unknown'),
    ],
  ),
  EnvironmentalSurveyQuestion(
    type: 'text',
    name: '_149_What_antigen_wa_ictim_immunized_with',
    label: '149. What antigen was the victim immunized with?',
    required: true,
    relevant: '\${_120_Is_the_affected_staff_imm} = \'yes\'',
  ),
  EnvironmentalSurveyQuestion(
    type: 'note',
    name: 'Training_Needs',
    label: 'Training Needs',
  ),
  EnvironmentalSurveyQuestion(
    type: 'select_one',
    name: '_122_Are_your_staff_regularly_',
    label: '150. Are your staff regularly trained in updated IPC protocols?',
    required: true,
    choices: [
      EnvironmentalSurveyChoice('yes', 'Yes'),
      EnvironmentalSurveyChoice('not_recently', 'Not Recently'),
      EnvironmentalSurveyChoice('no', 'No'),
    ],
  ),
  EnvironmentalSurveyQuestion(
    type: 'select_one',
    name: '_123_Do_your_staff_require_IPC',
    label: '151. Do your staff require IPC training?',
    required: true,
    relevant:
        '\${_122_Are_your_staff_regularly_} = \'no\' or \${_122_Are_your_staff_regularly_} = \'not_recently\'',
    choices: [
      EnvironmentalSurveyChoice('yes', 'Yes'),
      EnvironmentalSurveyChoice('no', 'No'),
    ],
  ),
  EnvironmentalSurveyQuestion(
    type: 'select_multiple',
    name: '_124_What_specific_training_wi',
    label:
        '152. What specific training will your staff need? (Select all that apply)',
    required: true,
    relevant: '\${_123_Do_your_staff_require_IPC} = \'yes\'',
    choices: [
      EnvironmentalSurveyChoice(
        'introduction_to_infection_prev',
        'Introduction to Infection Prevention and Control',
      ),
      EnvironmentalSurveyChoice(
        'chain_of_infection_and_modes_o',
        'Chain of Infection and Modes of Transmission',
      ),
      EnvironmentalSurveyChoice('hand_hygiene', 'Hand Hygiene '),
      EnvironmentalSurveyChoice(
        'use_of_personal_protective_equ',
        'Use of Personal Protective Equipment (PPE)',
      ),
      EnvironmentalSurveyChoice(
        'environmental_cleaning_and_dis',
        'Environmental Cleaning and Disinfection',
      ),
      EnvironmentalSurveyChoice(
        'healthcare_waste_management',
        'Healthcare Waste Management',
      ),
      EnvironmentalSurveyChoice(
        'sterilization_and_disinfection',
        'Sterilization and Disinfection of Instruments',
      ),
      EnvironmentalSurveyChoice(
        'respiratory_hygiene_and_cough_',
        'Respiratory Hygiene and Cough Etiquette',
      ),
      EnvironmentalSurveyChoice(
        'safe_injection_practices_and_s',
        'Safe Injection Practices and Sharps Safety',
      ),
      EnvironmentalSurveyChoice(
        'isolation_precautions',
        'Isolation Precautions',
      ),
      EnvironmentalSurveyChoice(
        'outbreak_detection_and_respons',
        'Outbreak Detection and Response',
      ),
      EnvironmentalSurveyChoice(
        'antimicrobial_resistance_and_s',
        'Antimicrobial Resistance and Stewardship',
      ),
      EnvironmentalSurveyChoice(
        'water__sanitation__and_hygiene',
        'Water, Sanitation, and Hygiene (WASH)',
      ),
      EnvironmentalSurveyChoice('others__specify', 'Others (Specify):'),
    ],
  ),
  EnvironmentalSurveyQuestion(
    type: 'text',
    name: 'Please_Specify_001',
    label: 'Please Specify:',
    required: true,
    relevant:
        'selected(\${_124_What_specific_training_wi}, \'others__specify\')',
  ),
  EnvironmentalSurveyQuestion(
    type: 'select_one',
    name: '_125_Would_you_be_happy_to_sub',
    label: '153. Would you be happy to submit a training request from IPC Team',
    required: true,
    relevant: '\${_123_Do_your_staff_require_IPC} = \'yes\'',
    choices: [
      EnvironmentalSurveyChoice('yes', 'Yes'),
      EnvironmentalSurveyChoice('no', 'No'),
    ],
  ),
  EnvironmentalSurveyQuestion(
    type: 'text',
    name: '_154_When_was_the_most_recent_',
    label: '154. When was the most recent training provided (Month/Year?',
    required: true,
    relevant: '\${_122_Are_your_staff_regularly_} = \'yes\'',
  ),
  EnvironmentalSurveyQuestion(
    type: 'text',
    name: '_155_Who_Provided_the_training',
    label: '155. Who Provided the training?',
    required: true,
    relevant: '\${_154_When_was_the_most_recent_} != \'\'',
  ),
  EnvironmentalSurveyQuestion(
    type: 'note',
    name: 'Thank_you_Please_su_Immunology_FTH_Gombe',
    label:
        'Thank you. Please submit your training request to the IPC Committee for review and follow-up.',
    relevant: '\${_125_Would_you_be_happy_to_sub} = \'yes\'',
  ),
  EnvironmentalSurveyQuestion(
    type: 'text',
    name: '_156_Any_other_comment',
    label: '156. Any other comment',
  ),
];
