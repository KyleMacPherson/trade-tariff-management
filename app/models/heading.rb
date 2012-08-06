class Heading < GoodsNomenclature
  include Tire::Model::Search

  plugin :json_serializer

  set_dataset filter("goods_nomenclatures.goods_nomenclature_item_id LIKE ?", '____000000').
              filter("goods_nomenclatures.goods_nomenclature_item_id NOT LIKE ?", '__00______').
              order(:goods_nomenclature_item_id.asc)

  set_primary_key :goods_nomenclature_sid

  one_to_many :commodities, dataset: -> {
    actual(Commodity).filter("goods_nomenclatures.goods_nomenclature_item_id LIKE ?", heading_id)
  }

  one_to_one :chapter, dataset: -> {
    actual(Chapter).filter("goods_nomenclatures.goods_nomenclature_item_id LIKE ?", chapter_id)
  }

  one_to_many :measures, dataset: -> {
    Measure.with_base_regulations
           .with_actual(BaseRegulation)
           .where(measures__goods_nomenclature_sid: uptree.map(&:goods_nomenclature_sid))
           .where{ ~{measures__measure_type: MeasureType::EXCLUDED_TYPES} }
    .union(
      Measure.with_modification_regulations
             .with_actual(ModificationRegulation)
             .where(measures__goods_nomenclature_sid: uptree.map(&:goods_nomenclature_sid))
             .where{ ~{measures__measure_type: MeasureType::EXCLUDED_TYPES} },
      alias: :measures
    )
    .with_actual(Measure)
    .order(:measures__geographical_area.asc)
  }

  one_to_many :import_measures, dataset: -> {
    measures_dataset.join(:measure_types, measure_type_id: :measure_type)
                    .where(trade_movement_code: MeasureType::IMPORT_MOVEMENT_CODES)
  }, class_name: 'Measure'

  one_to_many :export_measures, dataset: -> {
    measures_dataset.join(:measure_types, measure_type_id: :measure_type)
                    .where(trade_movement_code: MeasureType::EXPORT_MOVEMENT_CODES)
  }, class_name: 'Measure'

  dataset_module do
    def by_code(code = "")
      filter("goods_nomenclatures.goods_nomenclature_item_id LIKE ?", "#{code.to_s.first(4)}000000")
    end

    def by_declarable_code(code = "")
      filter(goods_nomenclature_item_id: code.to_s.first(10))
    end

    def declarable
      filter(producline_suffix: 80)
    end
  end

  delegate :section, to: :chapter

  def short_code
    goods_nomenclature_item_id.first(4)
  end

  # Override to avoid lookup, this is default behaviour for headings.
  def number_indents
    0
  end

  def to_param
    short_code
  end

  def uptree
    [self, self.chapter].compact
  end

  def declarable
    actual(GoodsNomenclature).where("goods_nomenclature_item_id LIKE ?", "#{short_code}______")
                             .count == 1
  end
  alias :declarable? :declarable

  def to_indexed_json
    {
      id: goods_nomenclature_sid,
      goods_nomenclature_item_id: goods_nomenclature_item_id,
      producline_suffix: producline_suffix,
      validity_start_date: validity_start_date,
      validity_end_date: validity_end_date,
      description: description,
      number_indents: number_indents,
      section: {
        numeral: section.numeral,
        title: section.title,
        position: section.position
      },
      chapter: {
        goods_nomenclature_sid: chapter.goods_nomenclature_sid,
        goods_nomenclature_item_id: chapter.goods_nomenclature_item_id,
        producline_suffix: chapter.producline_suffix,
        validity_start_date: chapter.validity_start_date,
        validity_end_date: chapter.validity_end_date,
        description: chapter.description.downcase
      },
    }.to_json
  end

  # TODO calculate real rate
  def third_country_duty_rate
    "0.00 %"
  end

  def uk_vat_rate
    "0.00 %"
  end
end
