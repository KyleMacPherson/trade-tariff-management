TradeTariffBackend::DataMigrator.migration do
  name "Add national footnote"

  FOOTNOTE_TYPE_ID = "05"
  FOOTNOTE_ID = "014"
  FOOTNOTE_DESCRIPTION = "Where the free rate of duty has been applied due to inclusion of 'Multi-component integrated circuits' (MCOs) document code Y035 (no status or reference required) must be declared at item level in box 44."
  VALIDITY_START_DATE = Date.new(2016, 9, 8)

  GOODS_NOMENCLATURE_ITEM_IDS = [
    "8422901000", "8422909000", "8431200011", "8431200019", "8431200030", "8431200040", "8431200050", "8431200080", "8450900000",
    "8466103100", "8466103800", "8466202000", "8466209100", "8466209800", "8466912000", "8466919500", "8466922000", "8466928000",
    "8466933000", "8466937090", "8466940000", "8476900020", "8476900090", "8504901110", "8504901120", "8504901190", "8504901810",
    "8504901899", "8504909910", "8504909920", "8504909990", "8518900010", "8518900030", "8518900040", "8518900050", "8518900060",
    "8518900080", "8518900091", "8518900099", "8522904920", "8522904930", "8522904950", "8522904960", "8522904965", "8522904970",
    "8522904990", "8529101100", "8529103100", "8529103900", "8529106590", "8529108020", "8529108050", "8529108060", "8529108070",
    "8529108090", "8529906515", "8529906520", "8529906525", "8529906530", "8529906540", "8529906545", "8529906550", "8529906565",
    "8529906570", "8529906575", "8529906580", "8529906585", "8529906590", "8529909210", "8529909215", "8529909225", "8529909230",
    "8529909232", "8529909235", "8529909236", "8529909237", "8529909240", "8529909241", "8529909242", "8529909243", "8529909245",
    "8529909247", "8529909249", "8529909250", "8529909255", "8529909265", "8529909270", "8529909275", "8529909285", "8529909299",
    "8529909720", "8529909740", "8529909790", "8530900000", "8535100010", "8535100090", "8535210010", "8535210090", "8535290010",
    "8535290090", "8535301010", "8535301090", "8535309010", "8535309090", "8535400010", "8535400090", "8535900010", "8535900020",
    "8535900030", "8535900090", "8536101010", "8536101090", "8536105010", "8536105090", "8536109010", "8536109090", "8536201010",
    "8536201090", "8536209010", "8536209090", "8536301010", "8536301090", "8536303010", "8536303011", "8536303090", "8536309010",
    "8536309090", "8536411010", "8536411090", "8536419010", "8536419040", "8536419089", "8536490010", "8536490030", "8536490091",
    "8536490099", "8536501110", "8536501131", "8536501132", "8536501135", "8536501199", "8536501510", "8536501590", "8536501910",
    "8536501991", "8536501993", "8536501999", "8536508010", "8536508081", "8536508082", "8536508083", "8536508093", "8536508097",
    "8536508098", "8536508099", "8536611010", "8536611090", "8536619010", "8536619090", "8536699010", "8536699051", "8536699060",
    "8536699081", "8536699082", "8536699083", "8536699084", "8536699085", "8536699086", "8536699087", "8536699088", "8536699099",
    "8536700010", "8536700090", "8536900110", "8536900190", "8536908510", "8536908520", "8536908530", "8536908540", "8536908592",
    "8536908594", "8536908595", "8536908597", "8536908599", "8537101010", "8537101090", "8537109110", "8537109130", "8537109150",
    "8537109160", "8537109199", "8537109910", "8537109930", "8537109935", "8537109940", "8537109945", "8537109950", "8537109960",
    "8537109970", "8537109992", "8537109993", "8537109994", "8537109996", "8537109998", "8537109999", "8537209110", "8537209190",
    "8537209910", "8537209990", "8538100010", "8538100090", "8538909110", "8538909120", "8538909189", "8538909910", "8538909930",
    "8538909940", "8538909950", "8538909992", "8538909995", "8538909999", "8548909010", "8548909041", "8548909043", "8548909044",
    "8548909048", "8548909050", "8548909060", "8548909065", "8548909099", "9025900090", "9027901000", "9027908000", "9032102090",
    "9032108190", "9032108990", "9032200090", "9032890020", "9032890030", "9032890040", "9032890090", "9032900090", "9033000090",
    "9114900010", "9114900090", "9305100000", "9305200010", "9305200090", "9305990000", "9306210000", "9306290010", "9306290090",
    "9306301000", "9306303000", "9306309000", "9306901000", "9306909000"
  ]

  def delete_footnote_and_associations
    Footnote::Operation.where(footnote_type_id: FOOTNOTE_TYPE_ID, footnote_id: FOOTNOTE_ID).delete
    FootnoteDescription::Operation.where(footnote_type_id: FOOTNOTE_TYPE_ID, footnote_id: FOOTNOTE_ID).delete
    FootnoteDescriptionPeriod::Operation.where(footnote_type_id: FOOTNOTE_TYPE_ID, footnote_id: FOOTNOTE_ID).delete
  end

  up do
    applicable {
      Footnote::Operation.where(footnote_type_id: FOOTNOTE_TYPE_ID, footnote_id: FOOTNOTE_ID).none? ||
      FootnoteDescription::Operation.where(footnote_type_id: FOOTNOTE_TYPE_ID, footnote_id: FOOTNOTE_ID, description: FOOTNOTE_DESCRIPTION).none? ||
      FootnoteDescriptionPeriod::Operation.where(footnote_type_id: FOOTNOTE_TYPE_ID, footnote_id: FOOTNOTE_ID).none?
    }

    apply {
      # make the run idempotent, delete records first if they exist
      delete_footnote_and_associations

      Footnote.new { |f|
        f.footnote_type_id = FOOTNOTE_TYPE_ID
        f.footnote_id = FOOTNOTE_ID
        f.national = true
        f.validity_start_date = VALIDITY_START_DATE
        f.operation_date = nil # as it came from initial import
      }.save

      FootnoteDescriptionPeriod.new { |fdp|
        fdp.footnote_description_period_sid = -218
        fdp.footnote_type_id = FOOTNOTE_TYPE_ID
        fdp.footnote_id = FOOTNOTE_ID
        fdp.validity_start_date = VALIDITY_START_DATE
        fdp.national = true
        fdp.operation_date = nil # as it came from initial import
      }.save

      FootnoteDescription.new { |fd|
        fd.footnote_description_period_sid = -218
        fd.language_id = "EN"
        fd.footnote_type_id = FOOTNOTE_TYPE_ID
        fd.footnote_id = FOOTNOTE_ID
        fd.national = true
        fd.description = FOOTNOTE_DESCRIPTION
        fd.operation_date = nil # as it came from initial import
      }.save
    }
  end

  down do
    applicable {
      Footnote::Operation.where(footnote_type_id: FOOTNOTE_TYPE_ID, footnote_id: FOOTNOTE_ID).any? ||
      FootnoteDescription::Operation.where(footnote_type_id: FOOTNOTE_TYPE_ID, footnote_id: FOOTNOTE_ID).any? ||
      FootnoteDescriptionPeriod::Operation.where(footnote_type_id: FOOTNOTE_TYPE_ID, footnote_id: FOOTNOTE_ID).any? ||
      FootnoteAssociationMeasure::Operation.where(footnote_type_id: FOOTNOTE_TYPE_ID, footnote_id: FOOTNOTE_ID).any?
    }

    apply {
      delete_footnote_and_associations
    }
  end
end
