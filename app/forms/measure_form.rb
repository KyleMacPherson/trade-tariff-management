class MeasureForm
  extend ActiveModel::Naming
  include ActiveModel::Conversion
  include ActiveModel::Validations

  attr_accessor :validity_start_date,
                :validity_end_date,
                :measure_type_series_id,
                :measure_type_id,
                :geographical_area_id,
                :goods_nomenclature_item_id,
                :geographical_area_sid,
                :goods_nomenclature_sid,
                :ordernumber,
                :additional_code_type_id,
                :additional_code_id,
                :additional_code_sid,
                :tariff_measure_number,
                :geographical_area_type,
                :geographical_area_proxy,
                :excluded_geographical_areas,
                :measure

  def initialize(measure)
    @measure = measure
  end

  def attributes=(attrs={})
    attrs.each do |k,v|
      self.public_send("#{k}=", v) if self.respond_to?("#{k}=")
    end
  end

  def measure_type_series_collection
    @series ||= MeasureTypeSeries.all
  end

  def measure_types_series_json
    series = measure_type_series_collection
    json = []

    series.each do |serie|
      json << {
        oid: serie.oid,
        measure_type_series_id: serie.measure_type_series_id,
        validity_start_date: serie.validity_start_date,
        validity_end_date: serie.validity_end_date,
        description: serie.description
      }
    end

    json
  end

  #TODO: cache this
  def measure_types_json
    types = MeasureType.all
    json = []

    types.each do |type|
      json << {
        oid: type.oid,
        measure_type_id: type.measure_type_id,
        measure_type_series_id: type.measure_type_series_id,
        validity_start_date: type.validity_start_date,
        validity_end_date: type.validity_end_date,
        measure_type_acronym: type.measure_type_acronym,
        description: type.description
      }
    end

    json
  end

  def measure_types_collection
    if measure_type_series_id.present?
      MeasureType.where(measure_type_series_id: measure_type_series_id)
    else
      MeasureType.all
    end
  end

  def geographical_groups_except_erga_omnes
    GeographicalArea.groups.exclude(geographical_area_id: GeographicalArea::ERGA_OMNES)
  end

  def geographical_area_erga_omnes
    GeographicalArea.where(geographical_area_id: GeographicalArea::ERGA_OMNES).first
  end

  def geographical_areas_json
    json = {}

    GeographicalArea.all.each do |group|
      json[group.geographical_area_id] = []

      group.contained_geographical_areas.each do |child|
        json[group.geographical_area_id] << {
          geographical_area_id: child.geographical_area_id,
          description: child.description
        }
      end
    end

    json
  end
end