require 'rails_helper'

describe TradeTariffBackend::Validations::ValidityDatesValidation do
  describe '#valid?' do
    let(:validation) { described_class.new(:vld1, 'validity_date') }

    context 'no validity start dates present' do
      let(:record) {
        double(validity_start_date: nil,
                          validity_end_date: nil)
      }

      it 'returns true' do
        expect(validation).to be_valid(record)
      end
    end

    context 'only validity start date present' do
      let(:record) {
        double(validity_start_date: Date.current,
                          validity_end_date: nil)
      }

      it 'returns true' do
        expect(validation).to be_valid(record)
      end
    end

    context 'validity end date is greater than validity start date' do
      let(:record) {
        double(validity_start_date: Date.yesterday,
                          validity_end_date: Date.current)
      }

      it 'returns true' do
        expect(validation).to be_valid(record)
      end
    end

    context 'validity start date is greater than validity end date' do
      let(:record) {
        double(validity_start_date: Date.current,
                          validity_end_date: Date.yesterday)
      }

      it 'returns false' do
        expect(validation).not_to be_valid(record)
      end
    end
  end
end
