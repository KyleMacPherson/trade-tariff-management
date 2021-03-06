require 'goods_nomenclature_mapper'

class GoodsNomenclature < Sequel::Model
  extend ActiveModel::Naming

  include ::XmlGeneration::BaseHelper
  include OwnValidityPeriod

  set_dataset order(Sequel.asc(:goods_nomenclatures__goods_nomenclature_item_id))
  set_primary_key [:goods_nomenclature_sid]

  plugin :time_machine, period_start_column: Sequel.qualify(:goods_nomenclatures, :validity_start_date),
                        period_end_column:   Sequel.qualify(:goods_nomenclatures, :validity_end_date)
  plugin :oplog, primary_key: :goods_nomenclature_sid
  plugin :nullable
  plugin :conformance_validator
  plugin :active_model

  plugin :sti, class_determinator: ->(record) {
    record.child_class_name
  }

  def child_class_name
    gono_id = goods_nomenclature_item_id.to_s

    if gono_id.ends_with?('00000000')
      'Chapter'
    elsif gono_id.ends_with?('000000') && gono_id.slice(2, 2) != '00'
      'Heading'
    elsif !gono_id.ends_with?('000000')
      'Commodity'
    else
      'GoodsNomenclature'
    end
  end

  def sti_instance
    if child_class_name == self.class.to_s
      self
    else
      klass = Object.const_get child_class_name
      klass.find(goods_nomenclature_item_id: goods_nomenclature_item_id)
    end
  end

  one_to_many :goods_nomenclature_indents, key: :goods_nomenclature_sid,
                                           primary_key: :goods_nomenclature_sid do |ds|
    ds.with_actual(GoodsNomenclatureIndent, self)
      .order(Sequel.desc(:goods_nomenclature_indents__validity_start_date))
  end

  def goods_nomenclature_indent
    goods_nomenclature_indents(reload: true).first
  end

  many_to_many :goods_nomenclature_descriptions, join_table: :goods_nomenclature_description_periods,
                                                 left_primary_key: :goods_nomenclature_sid,
                                                 left_key: :goods_nomenclature_sid,
                                                 right_key: %i[goods_nomenclature_description_period_sid goods_nomenclature_sid],
                                                 right_primary_key: %i[goods_nomenclature_description_period_sid goods_nomenclature_sid] do |ds|
    ds.with_actual(GoodsNomenclatureDescriptionPeriod, self)
      .order(Sequel.desc(:goods_nomenclature_description_periods__validity_start_date))
  end

  def goods_nomenclature_description
    goods_nomenclature_descriptions(reload: true).first || NullGoodsNomenclature.new
  end

  many_to_many :footnotes, join_table: :footnote_association_goods_nomenclatures,
                           left_primary_key: :goods_nomenclature_sid,
                           left_key: :goods_nomenclature_sid,
                           right_key: %i[footnote_type footnote_id],
                           right_primary_key: %i[footnote_type_id footnote_id] do |ds|
    ds.with_actual(FootnoteAssociationGoodsNomenclature)
  end

  def footnote
    footnotes(reload: true).first
  end

  one_to_one :national_measurement_unit_set, key: :cmdty_code,
                                             primary_key: :goods_nomenclature_item_id do |ds|
    ds.with_actual(Chief::Comm)
  end

  delegate :national_measurement_unit_set_units, to: :national_measurement_unit_set, allow_nil: true

  delegate :number_indents, to: :goods_nomenclature_indent, allow_nil: true
  delegate :description, :formatted_description, to: :goods_nomenclature_description, allow_nil: true

  one_to_one :goods_nomenclature_origin, key: %i[goods_nomenclature_item_id
                                                 productline_suffix],
                                         primary_key: %i[goods_nomenclature_item_id
                                                         producline_suffix]

  one_to_many :goods_nomenclature_successors, key: %i[absorbed_goods_nomenclature_item_id
                                                      absorbed_productline_suffix],
                                              primary_key: %i[goods_nomenclature_item_id
                                                              producline_suffix]

  one_to_many :export_refund_nomenclatures, key: :goods_nomenclature_sid,
                                            primary_key: :goods_nomenclature_sid do |ds|
    ds.with_actual(ExportRefundNomenclature)
  end

  one_to_many :measures, key: :goods_nomenclature_sid,
                         foreign_key: :goods_nomenclature_sid

  dataset_module do
    def by_code(code = "")
      filter(goods_nomenclature_item_id: code.to_s.first(10))
    end

    def declarable
      filter(producline_suffix: "80")
    end

    def non_hidden
      filter(Sequel.~(goods_nomenclature_item_id: HiddenGoodsNomenclature.codes))
    end

    def indexable
      where(Sequel.~(goods_nomenclature_item_id: HiddenGoodsNomenclature.codes))
    end
  end

  def id
    goods_nomenclature_sid
  end

  def to_s
    "#{number_indents}: #{goods_nomenclature_item_id}: #{description}"
  end

  def heading_id
    "#{goods_nomenclature_item_id.first(4)}______"
  end

  def chapter_id
    goods_nomenclature_item_id.first(2) + "0" * 8
  end

  def code
    goods_nomenclature_item_id
  end

  def bti_url
    "http://ec.europa.eu/taxation_customs/dds2/ebti/ebti_consultation.jsp?Lang=en&nomenc=#{code}&Expand=true"
  end

  def chapter?
    gono_id = goods_nomenclature_item_id.to_s

    gono_id.ends_with?('00000000')
  end

  def heading?
    gono_id = goods_nomenclature_item_id.to_s

    gono_id.ends_with?('000000') && gono_id.slice(2, 2) != '00'
  end

  def commodity?
    gono_id = goods_nomenclature_item_id.to_s

    !gono_id.ends_with?('000000')
  end

  def good_nomenclature?
    !(chapter? || heading? || commodity?)
  end

  def declarable?
    producline_suffix == '80' && children.none?
  end

  # To be refactored out
  one_to_many :commodities, dataset: -> {
    actual_or_relevant(Commodity)
             .filter("goods_nomenclatures.goods_nomenclature_item_id LIKE ?", heading_id)
             .where(Sequel.~(goods_nomenclatures__goods_nomenclature_item_id: HiddenGoodsNomenclature.codes))
  }

  def children
    func = Proc.new {
      ::GoodsNomenclatureMapper.new(
        commodities_dataset.
          eager(:goods_nomenclature_indents, :goods_nomenclature_descriptions).
          all
      ).all.
        detect do |item|
        item.goods_nomenclature_sid == goods_nomenclature_sid
      end.try(:children) || []
    }

    if Rails.env.test? || Rails.env.development?
      # Do not cache it in Test and Development environments.
      #
      func.call
    else
      # Cache for 3 hours
      #
      Rails.cache.fetch("commodity_#{goods_nomenclature_sid}_children", expires_in: 3.hours) do
        func.call
      end
    end
  end

  def record_code
    "400".freeze
  end

  def subrecord_code
    "00".freeze
  end

  def to_json(_options = {})
    {
      goods_nomenclature_item_id: code
    }
  end
end
