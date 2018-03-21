require 'rails_helper'

describe "Main XML generation" do

  include_context "xml_generation_base_context"

  let(:additional_code) do
    create(:additional_code, :xml)
  end

  let(:transmission_comment) do
    create(:transmission_comment, :xml)
  end

  let(:measure) do
    create(:measure, :xml)
  end

  let(:db_record) do
    [
      additional_code,
      transmission_comment,
      measure
    ]
  end

  let(:xml_envelope_node) do
    hash_xml["env:envelope"]
  end

  let(:xml_transaction_nodes) do
    xml_envelope_node["env:transaction"]
  end

  let(:xml_additional_code_transaction_node) do
    xml_transaction_nodes[0]
  end

  let(:xml_transmission_comment_transaction_node) do
    xml_transaction_nodes[1]
  end

  let(:xml_measure_transaction_node) do
    xml_transaction_nodes[2]
  end

  before do
    db_record
  end

  it "should return valid XML" do
    expect(xml_envelope_node["id"]).not_to be_nil
    expect(xml_envelope_node["xmlns"]).to be_eql("urn:publicid:-:DGTAXUD:TARIC:MESSAGE:1.0")
    expect(xml_envelope_node["xmlns:env"]).to be_eql("urn:publicid:-:DGTAXUD:GENERAL:ENVELOPE:1.0")
    expect(xml_transaction_nodes.size).to be_eql(3)

    transaction_node_expect_to_be_valid(xml_additional_code_transaction_node, "additional_code")
    transaction_node_expect_to_be_valid(xml_transmission_comment_transaction_node, "transmission_comment")
    transaction_node_expect_to_be_valid(xml_measure_transaction_node, "measure")
  end

  def transaction_node_expect_to_be_valid(transaction_node, data_node_name)
    message_node = transaction_node["env:app.message"]
    transmission_node = message_node["oub:transmission"]
    record_node = transmission_node["oub:record"]
    data_node_name = data_node_name.gsub("_", ".") if data_node_name.include?("_")
    data_item_node = record_node["oub:#{data_node_name}"]

    expect(transaction_node["id"]).not_to be_nil
    expect(message_node["id"]).not_to be_nil

    expect(transmission_node["xmlns:oub"]).to be_eql("urn:publicid:-:DGTAXUD:TARIC:MESSAGE:1.0")
    expect(transmission_node["xmlns:env"]).to be_eql("urn:publicid:-:DGTAXUD:GENERAL:ENVELOPE:1.0")

    expect(record_node["oub:transaction.id"]).not_to be_nil
    expect(record_node["oub:record.code"]).not_to be_nil
    expect(record_node["oub:subrecord.code"]).not_to be_nil
    expect(record_node["oub:record.sequence.number"]).not_to be_nil
    expect(record_node["oub:update.type"]).not_to be_nil

    expect(data_item_node).not_to be_nil
  end
end