require 'rails_helper'

describe "Certificate XML generation" do
  let(:db_record) do
    create(:certificate, :xml)
  end

  let(:data_namespace) do
    "oub:certificate"
  end

  let(:fields_to_check) do
    %i[
      certificate_type_code
      certificate_code
      validity_start_date
      validity_end_date
    ]
  end

  include_context "xml_generation_record_context"
end
