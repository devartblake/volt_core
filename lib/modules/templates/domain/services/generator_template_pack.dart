import '../entities/template_entities.dart';

typedef TemplatePackIdFactory = String Function(String seed);

/// Canonical Phase 3 template definitions for Voltcore's existing generator
/// inspection and maintenance workflows.
///
/// IDs are supplied by the caller so a migration/seed can choose deterministic
/// UUIDs per tenant. Field keys are intentionally stable and mirror legacy
/// semantics so adapters and parity tests do not depend on database row IDs.
class GeneratorTemplatePack {
  const GeneratorTemplatePack._();

  static FormTemplateDefinition inspection({
    required String tenantId,
    required DateTime now,
    required TemplatePackIdFactory idFactory,
  }) => _build(
        tenantId: tenantId,
        slug: 'generator-inspection',
        name: 'Generator Inspection',
        title: 'Generator Inspection v1',
        description: 'Generator inspection and compliance workflow.',
        now: now,
        idFactory: idFactory,
        settings: const {
          'pack': 'generator',
          'legacySource': 'InspectionEntity',
          'externalLegacyCollections': ['load_tests', 'photo_attachments'],
        },
        sections: const [
          _SectionSpec('site_generator', 'Site & Generator', [
            _FieldSpec('siteCode', 'Site code', TemplateFieldType.text, required: true),
            _FieldSpec('address', 'Address', TemplateFieldType.text, required: true),
            _FieldSpec('serviceDate', 'Service date', TemplateFieldType.date, required: true),
            _FieldSpec('technicianName', 'Technician', TemplateFieldType.text),
            _FieldSpec('generatorMake', 'Generator make', TemplateFieldType.text),
            _FieldSpec('generatorModel', 'Generator model', TemplateFieldType.text),
            _FieldSpec('generatorSerial', 'Generator serial', TemplateFieldType.text),
            _FieldSpec('generatorKw', 'Generator kW', TemplateFieldType.reading, validation: {'unit': 'kW'}),
            _FieldSpec('engineHours', 'Engine hours', TemplateFieldType.reading, validation: {'unit': 'h'}),
            _FieldSpec('fuelType', 'Fuel type', TemplateFieldType.select, options: ['Diesel', 'Gasoline', 'NaturalGas', 'None']),
            _FieldSpec('voltageRating', 'Voltage rating', TemplateFieldType.text),
            _FieldSpec('siteGrade', 'Site grade', TemplateFieldType.select, options: ['Green', 'Amber', 'Red']),
          ]),
          _SectionSpec('location_safety', 'Location & Safety', [
            _FieldSpec('locIndoors', 'Indoors', TemplateFieldType.boolean),
            _FieldSpec('locOutdoors', 'Outdoors', TemplateFieldType.boolean),
            _FieldSpec('locRoof', 'Roof', TemplateFieldType.boolean),
            _FieldSpec('locBasement', 'Basement', TemplateFieldType.boolean),
            _FieldSpec('locOther', 'Other location', TemplateFieldType.text),
            _FieldSpec('dedicatedRoom2hr', 'Dedicated 2-hour room', TemplateFieldType.boolean),
            _FieldSpec('separateFromMainService', 'Separate from main service', TemplateFieldType.boolean),
            _FieldSpec('areaClear', 'Area clear', TemplateFieldType.boolean),
            _FieldSpec('labelsAndEStopVisible', 'Labels and E-stop visible', TemplateFieldType.boolean),
            _FieldSpec('extinguisherPresent', 'Fire extinguisher present', TemplateFieldType.boolean),
          ]),
          _SectionSpec('fdny_dep', 'FDNY / DEP', [
            _FieldSpec('fuelStoredType', 'Stored fuel type', TemplateFieldType.text),
            _FieldSpec('fuelQtyGallons', 'Fuel quantity', TemplateFieldType.reading, validation: {'unit': 'gal'}),
            _FieldSpec('fdnyPermit', 'FDNY permit', TemplateFieldType.select, options: ['Yes', 'No', 'Unknown', 'N/A']),
            _FieldSpec('c92OnSite', 'C-92 on site', TemplateFieldType.select, options: ['Yes', 'No', 'Unknown', 'N/A']),
            _FieldSpec('gasCutoffValve', 'Gas cutoff valve', TemplateFieldType.select, options: ['Yes', 'No', 'Unknown', 'N/A']),
            _FieldSpec('depSizeKw', 'DEP size', TemplateFieldType.reading, validation: {'unit': 'kW'}),
            _FieldSpec('depRegisteredCats', 'DEP registered categories', TemplateFieldType.select, options: ['Yes', 'No', 'Unknown', 'N/A']),
            _FieldSpec('depCertificateOperate', 'DEP certificate to operate', TemplateFieldType.select, options: ['Yes', 'No', 'Unknown', 'N/A']),
            _FieldSpec('tier4Compliant', 'Tier 4 compliant', TemplateFieldType.select, options: ['Yes', 'No', 'Unknown', 'N/A']),
            _FieldSpec('smokeOrStackTest', 'Smoke/stack test', TemplateFieldType.select, options: ['Yes', 'No', 'Unknown', 'N/A']),
            _FieldSpec('recordsKept5Years', 'Records kept 5 years', TemplateFieldType.boolean),
          ]),
          _SectionSpec('operational_use', 'Operational Use', [
            _FieldSpec('emergencyOnly', 'Emergency-only use', TemplateFieldType.boolean),
            _FieldSpec('estimatedAnnualRuntimeHours', 'Estimated annual runtime', TemplateFieldType.reading, validation: {'unit': 'h/year'}),
            _FieldSpec('fuelFor6hrs', 'Fuel for 6 hours', TemplateFieldType.select, options: ['Yes', 'No', 'Unknown', 'N/A']),
            _FieldSpec('notes', 'Notes', TemplateFieldType.text, validation: {'multiline': true}),
          ]),
          _SectionSpec('post_inspection', 'Post-Inspection', [
            _FieldSpec('gensetRunsUnderLoad', 'Genset runs under load', TemplateFieldType.boolean),
            _FieldSpec('voltageFrequencyOk', 'Voltage/frequency acceptable', TemplateFieldType.boolean),
            _FieldSpec('exhaustOk', 'Exhaust acceptable', TemplateFieldType.boolean),
            _FieldSpec('groundingBondingOk', 'Grounding/bonding acceptable', TemplateFieldType.boolean),
            _FieldSpec('controlPanelOk', 'Control panel acceptable', TemplateFieldType.boolean),
            _FieldSpec('safetyDevicesOk', 'Safety devices acceptable', TemplateFieldType.boolean),
            _FieldSpec('deficienciesDocumented', 'Deficiencies documented', TemplateFieldType.boolean),
            _FieldSpec('loadbankDone', 'Load-bank test done', TemplateFieldType.boolean),
            _FieldSpec('atsVerified', 'ATS verified', TemplateFieldType.boolean),
            _FieldSpec('fuelStoredOver1Yr', 'Fuel stored over one year', TemplateFieldType.boolean),
          ]),
          _SectionSpec('service_history', 'Service History', [
            _FieldSpec('lastServiceDate', 'Last service date', TemplateFieldType.text),
            _FieldSpec('oilFilterChangeDate', 'Oil filter change date', TemplateFieldType.text),
            _FieldSpec('fuelFilterDate', 'Fuel filter date', TemplateFieldType.text),
            _FieldSpec('coolantFlushDate', 'Coolant flush date', TemplateFieldType.text),
            _FieldSpec('batteryReplaceDate', 'Battery replacement date', TemplateFieldType.text),
            _FieldSpec('airFilterDate', 'Air filter date', TemplateFieldType.text),
          ]),
          _SectionSpec('signatures', 'Signatures', [
            _FieldSpec('technicianSignaturePath', 'Technician signature', TemplateFieldType.signature),
            _FieldSpec('technicianSigDate', 'Technician signature date', TemplateFieldType.date),
            _FieldSpec('customerName', 'Customer name', TemplateFieldType.text),
            _FieldSpec('customerSignaturePath', 'Customer signature', TemplateFieldType.signature),
            _FieldSpec('customerSigDate', 'Customer signature date', TemplateFieldType.date),
          ]),
        ],
      );

  static FormTemplateDefinition maintenance({
    required String tenantId,
    required DateTime now,
    required TemplatePackIdFactory idFactory,
  }) => _build(
        tenantId: tenantId,
        slug: 'generator-maintenance',
        name: 'Generator Maintenance',
        title: 'Generator Maintenance v1',
        description: 'Generator preventive and corrective maintenance workflow.',
        now: now,
        idFactory: idFactory,
        settings: const {
          'pack': 'generator',
          'legacySource': 'MaintenanceRecord',
        },
        sections: const [
          _SectionSpec('site_generator', 'Site & Generator', [
            _FieldSpec('siteCode', 'Site code', TemplateFieldType.text, required: true),
            _FieldSpec('address', 'Address', TemplateFieldType.text, required: true),
            _FieldSpec('dateOfService', 'Date of service', TemplateFieldType.date),
            _FieldSpec('technicianName', 'Technician', TemplateFieldType.text),
            _FieldSpec('generatorMake', 'Generator make', TemplateFieldType.text),
            _FieldSpec('generatorModel', 'Generator model', TemplateFieldType.text),
            _FieldSpec('generatorSerial', 'Generator serial', TemplateFieldType.text),
            _FieldSpec('generatorKw', 'Generator kW', TemplateFieldType.reading, validation: {'unit': 'kW'}),
            _FieldSpec('engineHours', 'Engine hours', TemplateFieldType.reading, validation: {'unit': 'h'}),
            _FieldSpec('fuelType', 'Fuel type', TemplateFieldType.text),
            _FieldSpec('lastFuelDeliveryDate', 'Last fuel delivery date', TemplateFieldType.text),
            _FieldSpec('voltageRating', 'Voltage rating', TemplateFieldType.text),
          ]),
          _SectionSpec('walkthrough', 'Initial Walkthrough', [
            _FieldSpec('generatorLocation', 'Generator location', TemplateFieldType.select, options: ['Indoors', 'Outdoors', 'Roof', 'Basement', 'Other']),
            _FieldSpec('generatorLocationOther', 'Other location', TemplateFieldType.text),
            _FieldSpec('enclosureDamaged', 'Enclosure damaged', TemplateFieldType.boolean),
            _FieldSpec('enclosureIntact', 'Enclosure intact', TemplateFieldType.boolean),
            _FieldSpec('noEnclosure', 'No enclosure', TemplateFieldType.boolean),
            _FieldSpec('visibleDamageOrLeaks', 'Visible damage or leaks', TemplateFieldType.boolean),
            _FieldSpec('areaClearOfHazards', 'Area clear of hazards', TemplateFieldType.boolean),
            _FieldSpec('warningLabelsVisible', 'Warning labels visible', TemplateFieldType.boolean),
            _FieldSpec('fireExtinguisherPresent', 'Fire extinguisher present', TemplateFieldType.boolean),
          ]),
          _SectionSpec('components', 'Components', [
            _FieldSpec('batteryNeedsReplace', 'Battery needs replacement', TemplateFieldType.boolean),
            _FieldSpec('batteryRecentlyReplaced', 'Battery recently replaced', TemplateFieldType.boolean),
            _FieldSpec('batteryMfgDate', 'Battery manufacture date', TemplateFieldType.text),
            _FieldSpec('batteryPartNo', 'Battery part number', TemplateFieldType.text),
            _FieldSpec('batteryType', 'Battery type', TemplateFieldType.select, options: ['Lead Acid', 'NiCad']),
            _FieldSpec('airFilterNeedsReplace', 'Air filter needs replacement', TemplateFieldType.boolean),
            _FieldSpec('airFilterRecentlyReplaced', 'Air filter recently replaced', TemplateFieldType.boolean),
            _FieldSpec('airFilterLastReplacedDate', 'Air filter last replaced', TemplateFieldType.text),
            _FieldSpec('airFilterPartNo', 'Air filter part number', TemplateFieldType.text),
            _FieldSpec('coolantLevel', 'Coolant level', TemplateFieldType.select, options: ['Full', '50%', 'Low']),
            _FieldSpec('coolantColor', 'Coolant color', TemplateFieldType.select, options: ['Green', 'Orange', 'Blue', 'Unknown']),
          ]),
          _SectionSpec('hoses', 'Hoses', [
            _FieldSpec('coolantHosesCompromised', 'Coolant hoses compromised', TemplateFieldType.boolean),
            _FieldSpec('coolantHosesRecommendChange', 'Recommend coolant hose change', TemplateFieldType.boolean),
            _FieldSpec('coolantHosesInfo', 'Coolant hose notes', TemplateFieldType.text),
            _FieldSpec('fuelHosesCompromised', 'Fuel hoses compromised', TemplateFieldType.boolean),
            _FieldSpec('fuelHosesRecommendChange', 'Recommend fuel hose change', TemplateFieldType.boolean),
            _FieldSpec('fuelHosesInfo', 'Fuel hose notes', TemplateFieldType.text),
            _FieldSpec('airIntakeHosesCompromised', 'Air intake hoses compromised', TemplateFieldType.boolean),
            _FieldSpec('airIntakeHosesRecommendChange', 'Recommend air intake hose change', TemplateFieldType.boolean),
            _FieldSpec('airIntakeHosesInfo', 'Air intake hose notes', TemplateFieldType.text),
            _FieldSpec('oilHosesCompromised', 'Oil hoses compromised', TemplateFieldType.boolean),
            _FieldSpec('oilHosesRecommendChange', 'Recommend oil hose change', TemplateFieldType.boolean),
            _FieldSpec('oilHosesInfo', 'Oil hose notes', TemplateFieldType.text),
            _FieldSpec('additionalHosesCompromised', 'Additional hoses compromised', TemplateFieldType.boolean),
            _FieldSpec('additionalHosesRecommendChange', 'Recommend additional hose change', TemplateFieldType.boolean),
            _FieldSpec('additionalHosesInfo', 'Additional hose notes', TemplateFieldType.text),
          ]),
          _SectionSpec('filters', 'Filters & Canisters', [
            _FieldSpec('canLube', 'Lube canister needed', TemplateFieldType.boolean),
            _FieldSpec('canLubePartNo', 'Lube part number', TemplateFieldType.text),
            _FieldSpec('canFuel', 'Fuel canister needed', TemplateFieldType.boolean),
            _FieldSpec('canFuelPartNo', 'Fuel part number', TemplateFieldType.text),
            _FieldSpec('canWaterSep', 'Water separator needed', TemplateFieldType.boolean),
            _FieldSpec('canWaterSepPartNo', 'Water separator part number', TemplateFieldType.text),
            _FieldSpec('canOil', 'Oil canister needed', TemplateFieldType.boolean),
            _FieldSpec('canOilPartNo', 'Oil part number', TemplateFieldType.text),
            _FieldSpec('canOther1', 'Other canister 1 needed', TemplateFieldType.boolean),
            _FieldSpec('canOther1Label', 'Other canister 1 label', TemplateFieldType.text),
            _FieldSpec('canOther1PartNo', 'Other canister 1 part number', TemplateFieldType.text),
            _FieldSpec('canOther2', 'Other canister 2 needed', TemplateFieldType.boolean),
            _FieldSpec('canOther2Label', 'Other canister 2 label', TemplateFieldType.text),
            _FieldSpec('canOther2PartNo', 'Other canister 2 part number', TemplateFieldType.text),
          ]),
          _SectionSpec('actions', 'Maintenance Actions', [
            _FieldSpec('oilFilterChanged', 'Oil/filter changed', TemplateFieldType.boolean),
            _FieldSpec('oilFilterNotes', 'Oil/filter notes', TemplateFieldType.text),
            _FieldSpec('fuelFilterReplaced', 'Fuel filter replaced', TemplateFieldType.boolean),
            _FieldSpec('fuelFilterNotes', 'Fuel filter notes', TemplateFieldType.text),
            _FieldSpec('coolantFlushed', 'Coolant flushed', TemplateFieldType.boolean),
            _FieldSpec('coolantNotes', 'Coolant notes', TemplateFieldType.text),
            _FieldSpec('batteryReplaced', 'Battery replaced', TemplateFieldType.boolean),
            _FieldSpec('batteryNotes', 'Battery notes', TemplateFieldType.text),
            _FieldSpec('airFilterReplaced', 'Air filter replaced', TemplateFieldType.boolean),
            _FieldSpec('airFilterNotes', 'Air filter notes', TemplateFieldType.text),
            _FieldSpec('beltsHosesReplaced', 'Belts/hoses replaced', TemplateFieldType.boolean),
            _FieldSpec('beltsHosesNotes', 'Belts/hoses notes', TemplateFieldType.text),
            _FieldSpec('blockHeaterTested', 'Block heater tested', TemplateFieldType.boolean),
            _FieldSpec('blockHeaterNotes', 'Block heater notes', TemplateFieldType.text),
            _FieldSpec('racorServiced', 'Racor serviced', TemplateFieldType.boolean),
            _FieldSpec('racorNotes', 'Racor notes', TemplateFieldType.text),
            _FieldSpec('atsControllerInspected', 'ATS controller inspected', TemplateFieldType.boolean),
            _FieldSpec('atsControllerNotes', 'ATS controller notes', TemplateFieldType.text),
            _FieldSpec('cdvrProgrammed', 'CDVR programmed', TemplateFieldType.boolean),
            _FieldSpec('cdvrNotes', 'CDVR notes', TemplateFieldType.text),
            _FieldSpec('undervoltageRepaired', 'Undervoltage repaired', TemplateFieldType.boolean),
            _FieldSpec('undervoltageNotes', 'Undervoltage notes', TemplateFieldType.text),
            _FieldSpec('hazmatRemoved', 'Hazmat removed', TemplateFieldType.boolean),
            _FieldSpec('hazmatNotes', 'Hazmat notes', TemplateFieldType.text),
            _FieldSpec('serviceObservations', 'Service observations', TemplateFieldType.text, validation: {'multiline': true}),
          ]),
          _SectionSpec('post_service', 'Post-Service Checklist', [
            _FieldSpec('postVerifyRunsUnderLoad', 'Runs under load', TemplateFieldType.boolean),
            _FieldSpec('postCheckVoltFreq', 'Voltage/frequency checked', TemplateFieldType.boolean),
            _FieldSpec('postInspectExhaust', 'Exhaust inspected', TemplateFieldType.boolean),
            _FieldSpec('postVerifyGrounding', 'Grounding verified', TemplateFieldType.boolean),
            _FieldSpec('postCheckControlPanel', 'Control panel checked', TemplateFieldType.boolean),
            _FieldSpec('postEnsureSafetyDevices', 'Safety devices checked', TemplateFieldType.boolean),
            _FieldSpec('postDocumentDeficiencies', 'Deficiencies documented', TemplateFieldType.boolean),
            _FieldSpec('postLoadbankTest', 'Load-bank tested', TemplateFieldType.boolean),
            _FieldSpec('postAtsFunctionality', 'ATS functionality checked', TemplateFieldType.boolean),
            _FieldSpec('fuelStoredLong', 'Fuel stored long-term', TemplateFieldType.boolean),
          ]),
          _SectionSpec('parts', 'Parts & Materials', [
            _FieldSpec('partsOilTypeQty', 'Oil type/quantity', TemplateFieldType.text),
            _FieldSpec('partsCoolantTypeQty', 'Coolant type/quantity', TemplateFieldType.text),
            _FieldSpec('partsFilterTypes', 'Filter types', TemplateFieldType.text),
            _FieldSpec('partsBatteryTypeDate', 'Battery type/date', TemplateFieldType.text),
            _FieldSpec('partsBeltsHosesReplaced', 'Belts/hoses replaced', TemplateFieldType.text),
            _FieldSpec('partsBlockHeaterWattage', 'Block heater wattage', TemplateFieldType.text),
            _FieldSpec('partsCdvrSerial', 'CDVR serial', TemplateFieldType.text),
            _FieldSpec('generalNotes', 'General notes', TemplateFieldType.text, validation: {'multiline': true}),
            _FieldSpec('requiresFollowUp', 'Requires follow-up', TemplateFieldType.boolean),
            _FieldSpec('followUpNotes', 'Follow-up notes', TemplateFieldType.text, validation: {'multiline': true}),
          ]),
          _SectionSpec('signatures', 'Signatures', [
            _FieldSpec('technicianSignatureName', 'Technician signature name', TemplateFieldType.text),
            _FieldSpec('technicianSignatureDate', 'Technician signature date', TemplateFieldType.date),
            _FieldSpec('technicianSignaturePath', 'Technician signature', TemplateFieldType.signature),
            _FieldSpec('customerSignatureName', 'Customer signature name', TemplateFieldType.text),
            _FieldSpec('customerSignatureDate', 'Customer signature date', TemplateFieldType.date),
            _FieldSpec('customerSignaturePath', 'Customer signature', TemplateFieldType.signature),
          ]),
        ],
      );

  static FormTemplateDefinition _build({
    required String tenantId,
    required String slug,
    required String name,
    required String title,
    required String description,
    required DateTime now,
    required TemplatePackIdFactory idFactory,
    required Map<String, dynamic> settings,
    required List<_SectionSpec> sections,
  }) {
    final templateId = idFactory('$tenantId:$slug:template');
    final revisionId = idFactory('$tenantId:$slug:revision:1');
    final template = FormTemplate(
      id: templateId,
      tenantId: tenantId,
      slug: slug,
      name: name,
      description: description,
      assetType: 'generator',
      createdAt: now,
      updatedAt: now,
    );
    final revision = FormTemplateRevision(
      id: revisionId,
      tenantId: tenantId,
      templateId: templateId,
      revisionNumber: 1,
      status: TemplateRevisionStatus.published,
      title: title,
      instructions: 'Complete every applicable section and document deficiencies.',
      settings: settings,
      publishedAt: now,
      createdAt: now,
      updatedAt: now,
    );

    final builtSections = <FormTemplateSection>[];
    final fields = <FormTemplateField>[];
    final options = <FormTemplateFieldOption>[];
    for (var sectionIndex = 0; sectionIndex < sections.length; sectionIndex++) {
      final spec = sections[sectionIndex];
      final sectionId = idFactory('$tenantId:$slug:section:${spec.key}');
      builtSections.add(FormTemplateSection(
        id: sectionId,
        tenantId: tenantId,
        revisionId: revisionId,
        key: spec.key,
        title: spec.title,
        position: sectionIndex,
      ));
      for (var fieldIndex = 0; fieldIndex < spec.fields.length; fieldIndex++) {
        final fieldSpec = spec.fields[fieldIndex];
        final fieldId = idFactory('$tenantId:$slug:field:${fieldSpec.key}');
        fields.add(FormTemplateField(
          id: fieldId,
          tenantId: tenantId,
          revisionId: revisionId,
          sectionId: sectionId,
          key: fieldSpec.key,
          label: fieldSpec.label,
          type: fieldSpec.type,
          position: fieldIndex,
          isRequired: fieldSpec.required,
          validation: fieldSpec.validation,
        ));
        for (var optionIndex = 0;
            optionIndex < fieldSpec.options.length;
            optionIndex++) {
          final value = fieldSpec.options[optionIndex];
          options.add(FormTemplateFieldOption(
            id: idFactory('$tenantId:$slug:field:${fieldSpec.key}:option:$value'),
            tenantId: tenantId,
            fieldId: fieldId,
            value: value,
            label: value,
            position: optionIndex,
          ));
        }
      }
    }
    return FormTemplateDefinition(
      template: template,
      revision: revision,
      sections: builtSections,
      fields: fields,
      options: options,
    );
  }
}

class _SectionSpec {
  const _SectionSpec(this.key, this.title, this.fields);
  final String key;
  final String title;
  final List<_FieldSpec> fields;
}

class _FieldSpec {
  const _FieldSpec(
    this.key,
    this.label,
    this.type, {
    this.required = false,
    this.validation = const {},
    this.options = const [],
  });
  final String key;
  final String label;
  final TemplateFieldType type;
  final bool required;
  final Map<String, dynamic> validation;
  final List<String> options;
}
