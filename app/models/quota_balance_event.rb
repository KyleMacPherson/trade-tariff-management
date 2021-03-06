class QuotaBalanceEvent < Sequel::Model
  include ::XmlGeneration::BaseHelper

  plugin :oplog, primary_key: %i[quota_definition_sid
                                 occurrence_timestamp]
  plugin :conformance_validator

  set_primary_key %i[quota_definition_sid occurrence_timestamp]

  many_to_one :quota_definition, key: :quota_definition_sid,
                                 primary_key: :quota_definition_sid

  dataset_module do
    def last
      order(Sequel.desc(:occurrence_timestamp)).first
    end
  end

  def self.status
    'open'
  end

  def record_code
    "375".freeze
  end

  def subrecord_code
    "00".freeze
  end
end
