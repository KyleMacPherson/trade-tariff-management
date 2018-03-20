class QuotaExhaustionEvent < Sequel::Model
  plugin :oplog, primary_key: :quota_definition_sid
  plugin :conformance_validator

  set_primary_key [:quota_definition_sid]

  many_to_one :quota_definition, key: :quota_definition_sid,
                                 primary_key: :quota_definition_sid

  def self.status
    'exhausted'
  end

  def record_code
    "375".freeze
  end

  def subrecord_code
    "15".freeze
  end
end
