require "rails_helper"

RSpec.describe WorkbasketServices::MeasureAssociationSavers::Conditions do
  describe "#valid?" do
    it "doesn't insert an extra oplog row for existing measures" do
      measure = create(:measure)
      condition_ops = {
        measure_condition_components: {
          foo: { duty_expression_id: 123 }
        }
      }
      saver = described_class.new(measure, {}, condition_ops)

      expect { saver.valid? }.
        not_to change { oplog_count_for_measure(measure) }.from(1)
    end

    it "persists a new measure for reference integrity" do
      measure = build(:measure)
      condition_ops = {
        measure_condition_components: {
          foo: { duty_expression_id: 123 }
        }
      }
      saver = described_class.new(measure, {}, condition_ops)

      expect { saver.valid? }.
        to change { oplog_count_for_measure(measure) }.from(0).to(1)

      expect(measure.exists?).to be true
    end
  end

  private

  def oplog_count_for_measure(measure)
    Measure::Operation.where(measure_sid: measure.measure_sid).count
  end
end
