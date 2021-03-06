require 'rails_helper'

describe Measure do
  describe '#id' do
    let(:measure) { build :measure }

    it 'is an alias to #measure_sid' do
      expect(measure.id).to eq measure.measure_sid
    end
  end

  describe '#generating_regulation' do
    let(:measure_of_base_regulation) { create :measure }
    let(:measure_of_modification_regulation) { create :measure, :with_modification_regulation }

    it 'returns relevant regulation that is generating the measure' do
      expect(measure_of_base_regulation.generating_regulation).to eq measure_of_base_regulation.base_regulation
      expect(measure_of_modification_regulation.generating_regulation).to eq measure_of_modification_regulation.modification_regulation
    end
  end

  describe '#measures with different dates' do
    it 'returns all measures that are relevant to the modification regulation' do
      Sequel::Model.db.run(%{
        INSERT INTO measures_oplog (measure_sid, measure_type_id, geographical_area_id, goods_nomenclature_item_id, validity_start_date, validity_end_date, measure_generating_regulation_role, measure_generating_regulation_id, justification_regulation_role, justification_regulation_id, stopped_flag, geographical_area_sid, goods_nomenclature_sid, ordernumber, additional_code_type_id, additional_code_id, additional_code_sid, reduction_indicator, export_refund_nomenclature_sid, national, tariff_measure_number, invalidated_by, invalidated_at, oid, operation, operation_date)
        VALUES
        (3445395, '103', '1011', '0805201000', '2016-01-01 00:00:00', '2016-02-29 00:00:00', 4, 'R1517542', 4, 'R1517542', false, 400, 68304, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 3071870, 'U', '2015-11-26'),
        (3445396, '103', '1011', '0805201000', '2016-03-01 00:00:00', '2016-10-31 00:00:00', 4, 'R1517542', 4, 'R1517542', false, 400, 68304, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 3071871, 'U', '2015-11-26'),
        (3445397, '103', '1011', '0805201000', '2016-11-01 00:00:00', '2016-12-31 00:00:00', 4, 'R1517542', 4, 'R1517542', false, 400, 68304, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 3071872, 'U', '2015-11-26');
      })
      Sequel::Model.db.run(%{
        INSERT INTO modification_regulations_oplog (modification_regulation_role, modification_regulation_id, validity_start_date, validity_end_date, published_date, officialjournal_number, officialjournal_page, base_regulation_role, base_regulation_id, replacement_indicator, stopped_flag, information_text, approved_flag, explicit_abrogation_regulation_role, explicit_abrogation_regulation_id, effective_end_date, complete_abrogation_regulation_role, complete_abrogation_regulation_id, oid, operation, operation_date)
        VALUES
        (4, 'R1517542', '2016-01-01 00:00:00', NULL, '2015-10-30', 'L 285', 1, 1, 'R8726580', 0, false, 'CN 2016 (Entry prices)', true, NULL, NULL, NULL, NULL, NULL, 26064, 'C', '2015-11-26');
      })
      Sequel::Model.db.run(%{
        INSERT INTO goods_nomenclatures_oplog (goods_nomenclature_sid, goods_nomenclature_item_id, producline_suffix, validity_start_date, validity_end_date, statistical_indicator, created_at, oid, operation, operation_date)
        VALUES
	      (68304, '0805201000', '80', '1998-01-01 00:00:00', NULL, 0, '2013-08-02 20:03:55', 37691, 'C', NULL),
        (70329, '0805201005', '80', '1999-01-01 00:00:00', NULL, 0, '2013-08-02 20:04:48', 39237, 'C', NULL);

        INSERT INTO goods_nomenclature_indents_oplog (goods_nomenclature_indent_sid, goods_nomenclature_sid, validity_start_date, number_indents, goods_nomenclature_item_id, productline_suffix, created_at, validity_end_date, oid, operation, operation_date)
        VALUES
	      (67883, 68304, '1998-01-01 00:00:00', 2, '0805201000', '80', '2013-08-02 20:03:55', NULL, 38832, 'C', NULL),
	      (69920, 70329, '1999-01-01 00:00:00', 3, '0805201005', '80', '2013-08-02 20:04:48', NULL, 40421, 'C', NULL);
      })

      expect(described_class.with_modification_regulations.all.count).to eq 3
      # Measures on a parent code should also be present (e.g. 0805201000 on 0805201005)
      expect(Commodity.by_code('0805201005').first.measures.count).to eq 3
      # In TimeMachine we should only see vaild/the correct measure (with start date within the time range)
      # expect(TimeMachine.at(DateTime.parse("2016-07-21")){ Measure.with_modification_regulations.with_actual(ModificationRegulation).all.count }).to eq 1
      expect(TimeMachine.at(DateTime.parse("2016-07-21")) { described_class.with_modification_regulations.with_actual(ModificationRegulation).all.first.measure_sid }).to eq 3445396
      expect(TimeMachine.at(DateTime.parse("2016-07-21")) { Commodity.by_code('0805201005').first.measures.count }).to eq 1
      expect(TimeMachine.at(DateTime.parse("2016-07-21")) { Commodity.by_code('0805201005').first.measures.first.measure_sid }).to eq 3445396
    end
  end

  # According to Taric guide
  describe '#validity_end_date' do
    let(:base_regulation) { create :base_regulation, effective_end_date: Date.yesterday }
    let(:measure) {
      create :measure, measure_generating_regulation_role: 1,
                                     base_regulation: base_regulation,
                                     validity_end_date: Date.today
    }

    context 'measure end date greater than generating regulation end date' do
      it 'returns validity end date of' do
        expect(measure.validity_end_date.to_date).to eq base_regulation.effective_end_date.to_date
      end
    end

    context 'measure end date lesser than generating regulation end date' do
      let(:base_regulation) { create :base_regulation, effective_end_date: Date.today }
      let(:measure) {
        create :measure, measure_generating_regulation_role: 1,
                                       base_regulation: base_regulation,
                                       validity_end_date: Date.yesterday
      }

      it 'returns validity end date of the measure' do
        expect(measure.validity_end_date.to_date).to eq measure.validity_end_date.to_date
      end
    end

    context 'generating regulation effective end date blank, measure end date blank' do
      let(:base_regulation) { create :base_regulation, effective_end_date: nil }
      let(:measure) {
        create :measure, measure_generating_regulation_role: 1,
                                       base_regulation: base_regulation,
                                       validity_end_date: nil
      }

      it 'returns validity end date of the measure' do
        expect(measure.validity_end_date).to be_blank
      end
    end

    context 'generating regulation effective end date blank, measure end date present' do
      let(:base_regulation) { create :base_regulation, effective_end_date: nil }
      let(:measure) {
        create :measure, measure_generating_regulation_role: 1,
                                       base_regulation: base_regulation,
                                       validity_end_date: Date.today
      }

      it 'returns validity end date of the measure' do
        expect(measure.validity_end_date).to be_blank
      end
    end

    context 'generating regulation effective end date present, measure end date blank' do
      let(:base_regulation) { create :base_regulation, effective_end_date: Date.today }
      let(:measure) {
        create :measure, measure_generating_regulation_role: 1,
                                       base_regulation: base_regulation,
                                       validity_end_date: nil
      }

      it 'returns validity end date of the measure' do
        expect(measure.validity_end_date.to_date).to eq Date.today
      end
    end

    context 'measure is national' do
      let(:base_regulation) { create :base_regulation, effective_end_date: Date.yesterday }
      let(:measure) {
        create :measure, measure_generating_regulation_role: 1,
                                       base_regulation: base_regulation,
                                       validity_end_date: Date.today,
                                       national: true
      }

      it 'returns validity end date of the measure' do
        expect(measure.validity_end_date.to_date).to eq Date.today
      end
    end
  end

  describe 'associations' do
    describe 'measure type' do
      let!(:measure)         { create :measure }
      let!(:measure_type1)   {
        create :measure_type, measure_type_id: measure.measure_type_id,
                                                     validity_start_date: 5.years.ago,
                                                     validity_end_date: 3.years.ago,
                                                     operation_date: Date.yesterday
      }
      let!(:measure_type2) {
        create :measure_type, measure_type_id: measure.measure_type_id,
                                                     validity_start_date: 2.years.ago,
                                                     validity_end_date: nil,
                                                     operation: :update
      }

      context 'direct loading' do
        it 'loads correct description respecting given actual time' do
          TimeMachine.now do
            expect(measure.measure_type.pk).to eq measure_type1.pk
          end
        end

        it 'loads correct description respecting given time' do
          TimeMachine.at(1.year.ago) do
            expect(measure.measure_type.pk).to eq measure_type1.pk
          end
        end
      end

      context 'eager loading' do
        it 'loads correct description respecting given actual time' do
          TimeMachine.now do
            expect(
              described_class.where(measure_sid: measure.measure_sid)
                          .eager(:measure_type)
                          .all
                          .first
                          .measure_type.pk
            ).to eq measure_type1.pk
          end
        end

        it 'loads correct description respecting given time' do
          TimeMachine.at(1.year.ago) do
            expect(
              described_class.where(measure_sid: measure.measure_sid)
                          .eager(:measure_type)
                          .all
                          .first
                          .measure_type.pk
            ).to eq measure_type1.pk
          end
        end
      end
    end

    describe 'measure conditions' do
      let!(:measure)                { create :measure }
      let!(:measure_condition1)     { create :measure_condition, measure_sid: measure.measure_sid }
      let!(:measure_condition2)     { create :measure_condition }

      context 'direct loading' do
        it 'loads associated measure conditions' do
          expect(measure.measure_conditions).to include measure_condition1
        end

        it 'does not load associated measure condition' do
          expect(measure.measure_conditions).not_to include measure_condition2
        end
      end

      context 'eager loading' do
        it 'loads associated measure conditions' do
          expect(
            described_class.where(measure_sid: measure.measure_sid)
                 .eager(:measure_conditions)
                 .all
                 .first
                 .measure_conditions
          ).to include measure_condition1
        end

        it 'does not load associated measure condition' do
          expect(
            described_class.where(measure_sid: measure.measure_sid)
                 .eager(:measure_conditions)
                 .all
                 .first
                 .measure_conditions
          ).not_to include measure_condition2
        end
      end

      describe 'ordering' do
        let!(:measure)                { create :measure }
        let!(:measure_condition1)     { create :measure_condition, measure_sid: measure.measure_sid, condition_code: 'L', component_sequence_number: 10 }
        let!(:measure_condition2)     { create :measure_condition, measure_sid: measure.measure_sid, condition_code: 'A', component_sequence_number: 1 }

        it 'loads conditions ordered by component sequence number ascending' do
          expect(measure.measure_conditions.first).to eq measure_condition2
          expect(measure.measure_conditions.last).to eq measure_condition1
        end
      end
    end

    describe 'geographical area' do
      let!(:geographical_area1)     { create :geographical_area, geographical_area_id: 'ab' }
      let!(:geographical_area2)     { create :geographical_area, geographical_area_id: 'de' }
      let!(:measure)                { create :measure, geographical_area_sid: geographical_area1.geographical_area_sid }

      context 'direct loading' do
        it 'loads associated measure conditions' do
          expect(measure.geographical_area.pk).to eq geographical_area1.pk
        end

        it 'does not load associated measure condition' do
          expect(measure.geographical_area.pk).not_to eq geographical_area2.pk
        end
      end

      context 'eager loading' do
        it 'loads associated measure conditions' do
          expect(
            described_class.where(measure_sid: measure.measure_sid)
                 .eager(:geographical_area)
                 .all
                 .first
                 .geographical_area.pk
          ).to eq geographical_area1.pk
        end

        it 'does not load associated measure condition' do
          expect(
            described_class.where(measure_sid: measure.measure_sid)
                 .eager(:geographical_area)
                 .all
                 .first
                 .geographical_area.pk
          ).not_to eq geographical_area2.pk
        end
      end
    end

    describe 'footnotes' do
      let!(:measure)          { create :measure }
      let!(:footnote1)        {
        create :footnote, validity_start_date: 2.years.ago,
                                                  validity_end_date: nil
      }
      let!(:footnote1_assoc) {
        create :footnote_association_measure, measure_sid: measure.measure_sid,
                                                                      footnote_id: footnote1.footnote_id,
                                                                      footnote_type_id: footnote1.footnote_type_id
      }
      let!(:footnote2) {
        create :footnote, validity_start_date: 5.years.ago,
                                                  validity_end_date: 3.years.ago
      }
      let!(:footnote2_assoc) {
        create :footnote_association_measure, measure_sid: measure.measure_sid,
                                                                      footnote_id: footnote2.footnote_id,
                                                                      footnote_type_id: footnote2.footnote_type_id
      }

      context 'direct loading' do
        it 'loads correct indent respecting given actual time' do
          TimeMachine.now do
            expect(
              measure.footnotes.map(&:pk)
            ).to include footnote1.pk
          end
        end

        it 'loads correct indent respecting given time' do
          TimeMachine.at(1.year.ago) do
            expect(
              measure.footnotes.map(&:pk)
            ).to include footnote1.pk
          end

          TimeMachine.at(4.years.ago) do
            expect(
              measure.reload.footnotes.map(&:pk)
            ).to include footnote2.pk
          end
        end
      end

      context 'order' do
        it 'loads items in alphabetical order by footnote_type_id asc' do
          TimeMachine.now do
            f1 = create(:footnote, validity_start_date: 2.years.ago, footnote_type_id: "02")
            create(:footnote_association_measure, measure_sid: measure.measure_sid,
                   footnote_id: f1.footnote_id,
                   footnote_type_id: f1.footnote_type_id)
            f2 = create(:footnote, validity_start_date: 2.years.ago, footnote_type_id: "00")
            create(:footnote_association_measure, measure_sid: measure.measure_sid,
                   footnote_id: f2.footnote_id,
                   footnote_type_id: f2.footnote_type_id)
            expect(measure.reload.footnotes.first).to eq(f2)
          end
        end

        it 'loads items in alphabetical order by footnote_id asc' do
          TimeMachine.now do
            f1 = create(:footnote, validity_start_date: 2.years.ago, footnote_type_id: "02", footnote_id: "123")
            create(:footnote_association_measure, measure_sid: measure.measure_sid,
                   footnote_id: f1.footnote_id,
                   footnote_type_id: f1.footnote_type_id)
            f2 = create(:footnote, validity_start_date: 2.years.ago, footnote_type_id: "02", footnote_id: "124")
            create(:footnote_association_measure, measure_sid: measure.measure_sid,
                   footnote_id: f2.footnote_id,
                   footnote_type_id: f2.footnote_type_id)
            expect(measure.reload.footnotes.first).to eq(f1)
          end
        end
      end

      context 'eager loading' do
        it 'loads correct indent respecting given actual time' do
          TimeMachine.now do
            expect(
              described_class.where(measure_sid: measure.measure_sid)
                          .eager(:footnotes)
                          .all
                          .first
                          .footnotes.map(&:pk)
            ).to include footnote1.pk
          end
        end

        it 'loads correct indent respecting given time' do
          TimeMachine.at(1.year.ago) do
            expect(
              described_class.where(measure_sid: measure.measure_sid)
                          .eager(:footnotes)
                          .all
                          .first
                          .footnotes(reload: true).map(&:pk)
            ).to include footnote1.pk
          end

          TimeMachine.at(4.years.ago) do
            expect(
              described_class.where(measure_sid: measure.measure_sid)
                          .eager(:footnotes)
                          .all
                          .first
                          .footnotes(reload: true).map(&:pk)
            ).to include footnote2.pk
          end
        end
      end
    end

    describe 'measure components' do
      let!(:measure)                { create :measure }
      let!(:measure_component1)     { create :measure_component, measure_sid: measure.measure_sid }
      let!(:measure_component2)     { create :measure_component }

      context 'direct loading' do
        it 'loads associated measure components' do
          expect(measure.measure_components).to include measure_component1
        end

        it 'does not load associated measure component' do
          expect(measure.measure_components).not_to include measure_component2
        end
      end

      context 'eager loading' do
        it 'loads associated measure components' do
          expect(
            described_class.where(measure_sid: measure.measure_sid)
                 .eager(:measure_components)
                 .all
                 .first
                 .measure_components
          ).to include measure_component1
        end

        it 'does not load associated measure component' do
          expect(
            described_class.where(measure_sid: measure.measure_sid)
                 .eager(:measure_components)
                 .all
                 .first
                 .measure_components
          ).not_to include measure_component2
        end
      end
    end

    describe 'additional code' do
      let!(:additional_code1)     { create :additional_code, validity_start_date: Date.today.ago(3.years) }
      let!(:additional_code2)     { create :additional_code, validity_start_date: Date.today.ago(5.years) }
      let!(:measure)              { create :measure, additional_code_sid: additional_code1.additional_code_sid }

      context 'direct loading' do
        it 'loads associated measure conditions' do
          expect(measure.additional_code).to eq additional_code1
        end

        it 'does not load associated measure condition' do
          expect(measure.additional_code).not_to eq additional_code2
        end
      end

      context 'eager loading' do
        it 'loads associated measure conditions' do
          expect(
            described_class.where(measure_sid: measure.measure_sid)
                 .eager(:additional_code)
                 .all
                 .first
                 .additional_code
          ).to eq additional_code1
        end

        it 'does not load associated measure condition' do
          expect(
            described_class.where(measure_sid: measure.measure_sid)
                 .eager(:additional_code)
                 .all
                 .first
                 .additional_code
          ).not_to eq additional_code2
        end
      end
    end

    describe 'quota order number' do
      let!(:quota_order_number1)     { create :quota_order_number, validity_start_date: Date.today.ago(3.years) }
      let!(:quota_order_number2)     { create :quota_order_number, validity_start_date: Date.today.ago(5.years) }
      let!(:measure)                 { create :measure, ordernumber: quota_order_number1.quota_order_number_id }

      context 'direct loading' do
        it 'loads associated measure conditions' do
          expect(measure.quota_order_number).to eq quota_order_number1
        end

        it 'does not load associated measure condition' do
          expect(measure.quota_order_number).not_to eq quota_order_number2
        end
      end

      context 'eager loading' do
        it 'loads associated measure conditions' do
          expect(
            described_class.where(measure_sid: measure.measure_sid)
                 .eager(:quota_order_number)
                 .all
                 .first
                 .quota_order_number
          ).to eq quota_order_number1
        end

        it 'does not load associated measure condition' do
          expect(
            described_class.where(measure_sid: measure.measure_sid)
                 .eager(:quota_order_number)
                 .all
                 .first
                 .quota_order_number
          ).not_to eq quota_order_number2
        end
      end
    end

    describe 'full temporary stop regulation' do
      let!(:fts_regulation1)        { create :fts_regulation, validity_start_date: Date.today.ago(3.years) }
      let!(:fts_regulation2)        { create :fts_regulation, validity_start_date: Date.today.ago(5.years) }
      let!(:fts_regulation_action1) { create :fts_regulation_action, fts_regulation_id: fts_regulation1.full_temporary_stop_regulation_id }
      let!(:fts_regulation_action2) { create :fts_regulation_action, fts_regulation_id: fts_regulation2.full_temporary_stop_regulation_id }
      let!(:measure)                { create :measure, measure_generating_regulation_id: fts_regulation_action1.stopped_regulation_id }

      context 'direct loading' do
        it 'loads associated full temporary stop regulation' do
          expect(measure.full_temporary_stop_regulation.pk).to eq fts_regulation1.pk
        end

        it 'does not load associated full temporary stop regulation' do
          expect(measure.full_temporary_stop_regulation.pk).not_to eq fts_regulation2.pk
        end
      end

      context 'eager loading' do
        it 'loads associated full temporary stop regulation' do
          expect(
            described_class.where(measure_sid: measure.measure_sid)
                 .eager(:full_temporary_stop_regulations)
                 .all
                 .first
                 .full_temporary_stop_regulation.pk
          ).to eq fts_regulation1.pk
        end

        it 'does not load associated full temporary stop regulation' do
          expect(
            described_class.where(measure_sid: measure.measure_sid)
                 .eager(:full_temporary_stop_regulations)
                 .all
                 .first
                 .full_temporary_stop_regulation.pk
          ).not_to eq fts_regulation2.pk
        end
      end
    end

    describe 'measure partial temporary stop' do
      let!(:mpt_stop1)        { create :measure_partial_temporary_stop, validity_start_date: Date.today.ago(3.years) }
      let!(:mpt_stop2)        { create :measure_partial_temporary_stop, validity_start_date: Date.today.ago(5.years) }
      let!(:measure)          { create :measure, measure_generating_regulation_id: mpt_stop1.partial_temporary_stop_regulation_id }

      context 'direct loading' do
        it 'loads associated full temporary stop regulation' do
          expect(measure.measure_partial_temporary_stop.pk).to eq mpt_stop1.pk
        end

        it 'does not load associated full temporary stop regulation' do
          expect(measure.measure_partial_temporary_stop.pk).not_to eq mpt_stop2.pk
        end
      end

      context 'eager loading' do
        it 'loads associated full temporary stop regulation' do
          expect(
            described_class.where(measure_sid: measure.measure_sid)
                 .eager(:measure_partial_temporary_stops)
                 .all
                 .first
                 .measure_partial_temporary_stop.pk
          ).to eq mpt_stop1.pk
        end

        it 'does not load associated full temporary stop regulation' do
          expect(
            described_class.where(measure_sid: measure.measure_sid)
                 .eager(:measure_partial_temporary_stops)
                 .all
                 .first
                 .measure_partial_temporary_stop.pk
          ).not_to eq mpt_stop2.pk
        end
      end
    end
  end

  describe 'validations' do
    # ME2 ME4 ME6 ME24 The <field name> must exist.
    it { is_expected.to validate_presence.of(:measure_type) }
    # ME4
    it { is_expected.to validate_presence.of(:geographical_area) }
    # ME6
    it { is_expected.to validate_presence.of(:goods_nomenclature) }
    # ME24
    it { is_expected.to validate_presence.of(:measure_generating_role_id) }
    it { is_expected.to validate_presence.of(:measure_generating_role_type) }
    # ME1 The combination of measure type + geographical area +
    #     goods nomenclature item id + additional code type + additional code +
    #     order number + reduction indicator + start date must be unique
    it {
      expect(subject).to validate_uniqueness.of(%i[measure_type_id
                                                   geographical_area_sid
                                                   goods_nomenclature_sid
                                                   additional_code_type_id
                                                   additional_code_id
                                                   ordernumber
                                                   reduction_indicator
                                                   validity_start_date])
    }
    # ME4 ME5
    it { is_expected.to validate_validity_date_span.of(:geographical_area) }
    # ME2 ME3
    it { is_expected.to validate_validity_date_span.of(:measure_type) }
    # ME6 ME8
    it { is_expected.to validate_validity_date_span.of(:goods_nomenclature) }
    # ME25 If the measures end date is specified (implicitly or explicitly)
    # then the start date of the measure must be less than
    # or equal to the end date
    it { is_expected.to validate_validity_dates }

    describe 'ME7' do
      let(:measure1) { create :measure, gono_producline_suffix: "80" }
      let(:measure2) { create :measure, gono_producline_suffix: "20" }

      it 'performs validation' do
        expect(measure1).to be_conformant
        expect(measure2).not_to be_conformant
      end
    end

    describe 'ME9' do
      context 'additional_code blank, goods nomenclature code blank' do
        let(:measure) {
          create :measure, additional_code_id: nil,
                                         goods_nomenclature_item_id: nil
        }

        it 'performs validation' do
          expect(measure).not_to be_conformant
        end
      end

      context 'additional_code present' do
        let(:measure) { create :measure, additional_code_id: '123' }

        it 'performs validation' do
          expect(measure).to be_conformant
        end
      end
    end

    describe 'ME10' do
      let(:measure1) { create :measure, :with_quota_order_number, order_number_capture_code: 1, ordernumber: nil }
      let(:measure2) { create :measure, :with_quota_order_number, order_number_capture_code: 2, ordernumber: '123' }
      let(:measure3) { create :measure, :with_quota_order_number, order_number_capture_code: 1, ordernumber: '123' }

      it 'performs validation' do
        expect(measure1).not_to be_conformant
        expect(measure2).not_to be_conformant
        expect(measure3).to     be_conformant
      end
    end

    describe 'ME12' do
      let(:measure1) { create :measure, :with_additional_code_type }
      let(:measure2) { create :measure, :with_related_additional_code_type }

      it 'performs validation' do
        expect(measure1).not_to be_conformant
        expect(measure2).to be_conformant
      end
    end

    describe 'ME13' do
      context 'additional code type meursing and attributes missing' do
        let(:additional_code_type) { create :additional_code_type, :meursing }
        let(:meursing_additional_code) { create :meursing_additional_code }
        let(:measure) {
          create :measure, :with_related_additional_code_type,
                                        additional_code_type_id: additional_code_type.additional_code_type_id,
                                        additional_code_sid: meursing_additional_code.meursing_additional_code_sid,
                                        additional_code_id: meursing_additional_code.additional_code,
                                        goods_nomenclature_item_id: nil,
                                        ordernumber: nil,
                                        reduction_indicator: nil
        }

        it 'is valid' do
          expect(measure).to be_conformant
        end
      end

      context 'additional code type meursing and attributes present' do
        let(:additional_code_type) { create :additional_code_type, :meursing }
        let(:measure) {
          create :measure, :with_related_additional_code_type,
                                         :with_quota_order_number,
                                        additional_code_type_id: additional_code_type.additional_code_type_id,
                                        additional_code_id: '123',
                                        goods_nomenclature_item_id: '1234567890',
                                        ordernumber: '12345',
                                        reduction_indicator: 1
        }

        it 'noes be valid' do
          expect(measure).not_to be_conformant
        end
      end

      context 'additional code type non meursing' do
        let(:measure) {
          create :measure, :with_related_additional_code_type,
                                        additional_code_type_id: 3
        }

        it 'is valid' do
          expect(measure).to be_conformant
        end
      end
    end

    describe 'ME14' do
      context 'additional code type meursing, additional code is associated to export refund nomenclature' do
        let(:additional_code) { create :additional_code, :with_export_refund_nomenclature }
        let(:measure) {
          create :measure, :with_related_additional_code_type,
                                         :with_quota_order_number,
                                        additional_code_type_id: 3,
                                        additional_code_id: additional_code.additional_code,
                                        goods_nomenclature_item_id: '1234567890',
                                        ordernumber: '12345',
                                        reduction_indicator: 1,
                                        order_number_capture_code: 1
        }

        it 'is valid' do
          expect(measure).to be_conformant
        end
      end

      context 'additional code type meursing, additional code is not associated to export refund nomenclature' do
        let(:additional_code) { create :additional_code }
        let(:measure) {
          create :measure, :with_related_additional_code_type,
                                         :with_quota_order_number,
                                        additional_code_type_id: 3,
                                        additional_code_id: additional_code.additional_code,
                                        goods_nomenclature_item_id: '1234567890',
                                        ordernumber: '12345',
                                        reduction_indicator: 1
        }

        it 'is not valid' do
          expect(measure).not_to be_conformant
        end
      end

      context 'additional code type non meursing' do
        let(:measure) {
          create :measure, :with_related_additional_code_type,
                                        additional_code_type_id: 3
        }

        it 'is valid' do
          expect(measure).to be_conformant
        end
      end
    end

    describe "ME16: Integrating a measure with an additional code when an equivalent or
              overlapping measures without additional code already exists and vice-versa,
              should be forbidden.", :pending do
      let!(:goods_nomenclature) { create(:goods_nomenclature) }
      let!(:additional_code) { create(:additional_code, validity_start_date: Date.yesterday) }

      it "runs validation successfully if there is no existing measure for additional code and vice versa" do
        pending("Rule commented out in c40a8679")
        fail

        measure = build(
          :measure,
          goods_nomenclature_item_id: goods_nomenclature.goods_nomenclature_item_id,
          additional_code_sid: additional_code.additional_code_sid,
          validity_start_date: Date.yesterday
        )

        expect(measure.additional_code).not_to be(nil)
        expect(measure).to be_conformant

        measure2 = build(
          :measure,
          goods_nomenclature_item_id: goods_nomenclature.goods_nomenclature_item_id,
          additional_code_sid: nil,
          validity_start_date: Date.yesterday
        )

        expect(measure2).to be_conformant
      end

      it "does not run validation successfully if there is an existing measure without additional code" do
        measure = build(
          :measure,
          goods_nomenclature_item_id: goods_nomenclature.goods_nomenclature_item_id,
          additional_code_sid: nil,
          validity_start_date: Date.yesterday
        )

        expect(measure).to be_conformant

        measure.save

        measure2 = build(
          :measure,
          goods_nomenclature_item_id: measure.goods_nomenclature_item_id,
          goods_nomenclature_sid: measure.goods_nomenclature_sid,
          additional_code_sid: additional_code.additional_code_sid,
          validity_start_date: measure.validity_start_date,
          measure_type_id: measure.measure_type_id,
          geographical_area_sid: measure.geographical_area_sid,
          ordernumber: measure.ordernumber,
          reduction_indicator: measure.reduction_indicator,
          additional_code_type_id: measure.additional_code_type_id,
          additional_code_id: measure.additional_code_id
        )

        expect(measure2.additional_code_sid).not_to be(nil)
        expect(measure2).not_to be_conformant
        expect(measure2.conformance_errors).to have_key(:ME16)
      end

      it "does not run validation successfully if there is an existing measure with additional code" do
        measure = build(
          :measure,
          goods_nomenclature_item_id: goods_nomenclature.goods_nomenclature_item_id,
          additional_code_sid: additional_code.additional_code_sid,
          validity_start_date: Date.yesterday
        )

        expect(measure).to be_conformant

        measure.save

        measure2 = build(
          :measure,
          goods_nomenclature_item_id: measure.goods_nomenclature_item_id,
          goods_nomenclature_sid: measure.goods_nomenclature_sid,
          additional_code_sid: nil,
          validity_start_date: measure.validity_start_date,
          measure_type_id: measure.measure_type_id,
          geographical_area_sid: measure.geographical_area_sid,
          ordernumber: measure.ordernumber,
          reduction_indicator: measure.reduction_indicator,
          additional_code_type_id: measure.additional_code_type_id,
          additional_code_id: measure.additional_code_id
        )

        expect(measure2.additional_code_sid).to be(nil)
        expect(measure2).not_to be_conformant
        expect(measure2.conformance_errors).to have_key(:ME16)
      end
    end

    describe 'ME17' do
      let(:measure_type) { create :measure_type }

      let!(:additional_code_type) {
        create(
          :additional_code_type,
          additional_code_type_id: "4",
          application_code: "0",
          validity_start_date: Date.yesterday
        )
      }

      let!(:additional_code_type_measure_type) {
        create(
          :additional_code_type_measure_type,
          additional_code_type_id: additional_code_type.additional_code_type_id,
          measure_type_id: measure_type.measure_type_id,
          validity_start_date: Date.yesterday,
        )
      }

      let!(:additional_code) {
        create(
          :additional_code,
          additional_code_type_id: additional_code_type.additional_code_type_id,
          validity_start_date: Date.yesterday,
        )
      }

      context "If the additional code type has as application 'non-Meursing' then the additional code must exist as a non-Meursing additional code." do
        let(:measure) {
          build(
            :measure,
            measure_type_id: measure_type.measure_type_id,
            additional_code_type_id: additional_code_type.additional_code_type_id,
            additional_code_id: additional_code.additional_code,
            additional_code_sid: additional_code.additional_code_sid,
            validity_start_date: Date.yesterday,
          )
        }

        it 'is valid' do
          expect(measure).to be_conformant
        end
      end

      context "If the additional code type has an application 'non-Meursing' and the additional code doesn't exist" do
        let(:measure) {
          build(
            :measure,
            measure_type_id: measure_type.measure_type_id,
            additional_code_type_id: additional_code_type.additional_code_type_id,
            additional_code_id: nil,
            additional_code_sid: nil,
            validity_start_date: Date.yesterday,
          )
        }

        it 'is invalid' do
          expect(measure).not_to be_conformant
          expect(measure.conformance_errors).to have_key(:ME17)
        end
      end
    end

    describe 'ME19' do
      let(:measure_type) { create :measure_type }

      let!(:additional_code_type) {
        create(
          :additional_code_type,
          additional_code_type_id: "4",
          application_code: "0",
          validity_start_date: Date.yesterday
        )
      }

      let!(:additional_code_type_measure_type) {
        create(
          :additional_code_type_measure_type,
          additional_code_type_id: additional_code_type.additional_code_type_id,
          measure_type_id: measure_type.measure_type_id,
          validity_start_date: Date.yesterday,
        )
      }

      let!(:additional_code) {
        create(
          :additional_code,
          additional_code_type_id: additional_code_type.additional_code_type_id,
          validity_start_date: Date.yesterday,
        )
      }

      let!(:additional_code2) {
        create(
          :additional_code,
          validity_start_date: Date.yesterday,
        )
      }

      let(:measure) {
        build(
          :measure,
          measure_type_id: measure_type.measure_type_id,
          additional_code_type_id: additional_code_type.additional_code_type_id,
          additional_code_id: additional_code.additional_code,
          additional_code_sid: additional_code.additional_code_sid,
          validity_start_date: Date.yesterday,
        )
      }

      let(:measure2) {
        build(
          :measure,
          measure_type_id: measure_type.measure_type_id,
          additional_code_type_id: additional_code_type.additional_code_type_id,
          additional_code_id: additional_code.additional_code,
          additional_code_sid: additional_code.additional_code_sid,
          validity_start_date: Date.yesterday,
          ordernumber: "090001"
        )
      }

      context "If the additional code type has as application 'ERN' then the goods code must be specified but the order number is blocked for input." do
        it 'is valid' do
          expect(measure).to be_conformant
        end

        it 'is invalid' do
          expect(measure2).not_to be_conformant
          expect(measure2.conformance_errors).to have_key(:ME19)
        end
      end
    end

    describe 'ME21' do
      let(:measure_type) { create :measure_type }

      let!(:additional_code_type) {
        create(
          :additional_code_type,
          additional_code_type_id: "4",
          application_code: "0",
          validity_start_date: Date.yesterday,
          validity_end_date: nil
        )
      }

      let!(:additional_code_type_measure_type) {
        create(
          :additional_code_type_measure_type,
          additional_code_type_id: additional_code_type.additional_code_type_id,
          measure_type_id: measure_type.measure_type_id,
          validity_start_date: Date.yesterday,
          validity_end_date: nil
        )
      }

      let!(:additional_code) {
        create(
          :additional_code,
          additional_code_type_id: additional_code_type.additional_code_type_id,
          validity_start_date: Date.yesterday,
          validity_end_date: nil
        )
      }

      context "If the additional code type has as application 'ERN' then the combination of goods code + additional code must exist as an ERN product code and its validity period must span the validity period of the measure" do
        it 'is valid' do
          measure = build(
            :measure,
            measure_type_id: measure_type.measure_type_id,
            additional_code_type_id: additional_code_type.additional_code_type_id,
            additional_code_id: additional_code.additional_code,
            additional_code_sid: additional_code.additional_code_sid,
            validity_start_date: Date.yesterday,
            validity_end_date: nil
          )

          expect(measure).to be_conformant
        end

        it 'is invalid' do
          measure = build(
            :measure,
            measure_type_id: measure_type.measure_type_id,
            additional_code_type_id: additional_code_type.additional_code_type_id,
            additional_code_id: additional_code.additional_code,
            additional_code_sid: additional_code.additional_code_sid,
            validity_start_date: Date.yesterday,
            validity_end_date: nil
          )

          additional_code_type = measure.additional_code_type
          additional_code_type.validity_start_date = measure.validity_start_date + 2.days
          additional_code_type.save

          expect(measure).not_to be_conformant
          expect(measure.conformance_errors).to have_key(:ME21)
        end
      end
    end

    describe 'ME26' do
      it {
        expect(subject).to validate_exclusion.of(%i[measure_generating_regulation_id measure_generating_regulation_role])
                                    .from(-> { CompleteAbrogationRegulation.select(:complete_abrogation_regulation_id, :complete_abrogation_regulation_role) })
      }
    end

    describe 'ME27' do
      let(:measure) { create :measure }

      context 'regulation fully replaced' do
        before { measure.generating_regulation.update(replacement_indicator: 1) }

        it 'is not valid' do
          expect(measure).not_to be_conformant
        end
      end

      context 'regulation partially replaced' do
        before { measure.generating_regulation.update(replacement_indicator: 2) }

        it 'is valid' do
          expect(measure).to be_conformant
        end
      end

      context 'regulation not replaced' do
        before { measure.generating_regulation.update(replacement_indicator: 0) }

        it 'is valid' do
          expect(measure).to be_conformant
        end
      end
    end

    describe "ME32: There may be no overlap in time with other measure occurrences with a goods code in the same nomenclature
              hierarchy which references the same measure type, geo area, order number, additional code and reduction indicator.
              This rule is not applicable for Meursing additional codes." do
      let!(:measure_type) { create :measure_type }
      let!(:goods_nomenclature) { create(:goods_nomenclature) }
      let!(:geographical_area) { create :geographical_area }
      let!(:additional_code_type) { create(:additional_code_type) }
      let!(:additional_code) {
        create(
          :additional_code,
            additional_code_sid: 1,
            additional_code_type_id: additional_code_type.additional_code_type_id,
            validity_start_date: Date.yesterday
)
      }
      let!(:additional_code_type_measure_type) {
        create(
          :additional_code_type_measure_type,
            additional_code_type: additional_code_type,
            measure_type_id: measure_type.measure_type_id,
            validity_start_date: Date.yesterday,
        )
      }
      let!(:meursing_additional_code_type) { create(:additional_code_type, :meursing) }
      let!(:meursing_additional_code) {
        create(
          :meursing_additional_code,
            meursing_additional_code_sid: 2,
            validity_start_date: Date.yesterday
)
      }
      let!(:meursing_additional_code_type_measure_type) {
        create(
          :additional_code_type_measure_type,
            additional_code_type_id: meursing_additional_code_type.additional_code_type_id,
            measure_type_id: measure_type.measure_type_id,
            validity_start_date: Date.yesterday,
        )
      }

      it "runs validation successfully if there is no existing measure with such criteria" do
        measure = build(
          :measure,
          goods_nomenclature_item_id: goods_nomenclature.goods_nomenclature_item_id,
          additional_code_sid: additional_code.additional_code_sid,
          additional_code_type: additional_code_type,
          measure_type_id: measure_type.measure_type_id,
          validity_start_date: Date.yesterday
        )

        expect(measure.additional_code).not_to be(nil)
        expect(measure.meursing_additional_code).to be(nil)
        expect(measure).to be_conformant
      end

      it "runs validation successfully if meursing additional code is present" do
        measure = build(
          :measure,
          goods_nomenclature_item_id: nil,
          additional_code_sid: meursing_additional_code.meursing_additional_code_sid,
          additional_code_id: meursing_additional_code.additional_code,
          additional_code_type_id: meursing_additional_code_type.additional_code_type_id,
          measure_type_id: measure_type.measure_type_id,
          validity_start_date: Date.yesterday
        )

        expect(measure.meursing_additional_code).not_to be(nil)
        expect(measure).to be_conformant
      end

      it "runs validation successfully if measure respect time machine w.r.t validity start date" do
        _measure = create(
          :measure,
          goods_nomenclature_item_id: goods_nomenclature.goods_nomenclature_item_id,
          additional_code_sid: additional_code.additional_code_sid,
          additional_code_type: additional_code_type,
          validity_start_date: 10.year.ago,
          validity_end_date: 2.year.ago
        )

        measure2 = build(
          :measure,
          goods_nomenclature_item_id: goods_nomenclature.goods_nomenclature_item_id,
          additional_code_sid: additional_code.additional_code_sid,
          validity_start_date: 10.year.ago,
          validity_end_date: 2.year.ago
        )

        measure2.validity_start_date = Date.yesterday
        measure2.validity_end_date = Date.yesterday + 2.years

        measure2.justification_regulation_id = 'abc'
        measure2.justification_regulation_role = 1

        expect(measure2.additional_code).not_to be(nil)
        expect(measure2).to be_conformant
      end

      it "fails validation if measure for such criteria is already present" do
        _measure = create(
          :measure,
          measure_type_id: measure_type.measure_type_id,
          goods_nomenclature_item_id: goods_nomenclature.goods_nomenclature_item_id,
          geographical_area_sid: geographical_area.geographical_area_sid,
          additional_code_sid: additional_code.additional_code_sid,
          additional_code_type: additional_code_type,
          additional_code_id: additional_code.additional_code,
          validity_start_date: Date.yesterday
        )

        measure2 = create(
          :measure,
          measure_type_id: measure_type.measure_type_id,
          goods_nomenclature_item_id: goods_nomenclature.goods_nomenclature_item_id,
          geographical_area_sid: geographical_area.geographical_area_sid,
          additional_code_sid: additional_code.additional_code_sid,
          additional_code_type: additional_code_type,
          additional_code_id: additional_code.additional_code,
          validity_start_date: Date.yesterday
        )

        expect(measure2.additional_code).not_to be(nil)
        expect(measure2).not_to be_conformant
        expect(measure2.conformance_errors).to have_key(:ME32)
      end

      it "fails validation for test case 1" do
        # Case 1: When validity start date of new measure is before
        # the existing measure's validity end date.
        _measure = create(
          :measure,
          measure_type_id: measure_type.measure_type_id,
          goods_nomenclature_item_id: goods_nomenclature.goods_nomenclature_item_id,
          geographical_area_sid: geographical_area.geographical_area_sid,
          additional_code_sid: additional_code.additional_code_sid,
          additional_code_type: additional_code_type,
          additional_code_id: additional_code.additional_code,
          validity_start_date: 1.year.ago,
          validity_end_date: Date.current + 1.month
        )

        new_measure = build(
          :measure,
          measure_type_id: measure_type.measure_type_id,
          goods_nomenclature_item_id: goods_nomenclature.goods_nomenclature_item_id,
          geographical_area_sid: geographical_area.geographical_area_sid,
          additional_code_sid: additional_code.additional_code_sid,
          additional_code_type: additional_code_type,
          additional_code_id: additional_code.additional_code,
        )

        new_measure.validity_start_date = Date.current
        new_measure.validity_end_date = nil

        new_measure.justification_regulation_id = "abc"
        new_measure.justification_regulation_role = 1

        expect(new_measure.additional_code).not_to be(nil)
        expect(new_measure).not_to be_conformant
        expect(new_measure.conformance_errors).to have_key(:ME32)
      end

      it "fails validation for test Case 2" do
        # Case 2: When new measure's validity start date is before
        # existing measure's validity start date and existing measure is having
        # validity end date as nil and new measure's is also having validity end
        # date as nil.

        _measure = create(
          :measure,
          measure_type_id: measure_type.measure_type_id,
          goods_nomenclature_item_id: goods_nomenclature.goods_nomenclature_item_id,
          geographical_area_sid: geographical_area.geographical_area_sid,
          additional_code_sid: additional_code.additional_code_sid,
          additional_code_type: additional_code_type,
          additional_code_id: additional_code.additional_code,
          validity_start_date: 1.year.ago,
          validity_end_date: nil
        )

        new_measure = build(
          :measure,
          measure_type_id: measure_type.measure_type_id,
          goods_nomenclature_item_id: goods_nomenclature.goods_nomenclature_item_id,
          geographical_area_sid: geographical_area.geographical_area_sid,
          additional_code_sid: additional_code.additional_code_sid,
          additional_code_type: additional_code_type,
          additional_code_id: additional_code.additional_code,
        )

        new_measure.validity_start_date = Date.current
        new_measure.validity_end_date = nil

        new_measure.justification_regulation_id = "abc"
        new_measure.justification_regulation_role = 1

        expect(new_measure.additional_code).not_to be(nil)
        expect(new_measure).not_to be_conformant
        expect(new_measure.conformance_errors).to have_key(:ME32)
      end

      it "fails validation for test case 3" do
        # Case 3:  When existing measure's validity start date is after new
        # measure's validity start date and existing measure is having validity
        # end date as nil.

        _measure = create(
          :measure,
          measure_type_id: measure_type.measure_type_id,
          goods_nomenclature_item_id: goods_nomenclature.goods_nomenclature_item_id,
          geographical_area_sid: geographical_area.geographical_area_sid,
          additional_code_sid: additional_code.additional_code_sid,
          additional_code_type: additional_code_type,
          additional_code_id: additional_code.additional_code,
          validity_start_date: Date.current + 1.month,
          validity_end_date: nil
        )

        new_measure = create(
          :measure,
          measure_type_id: measure_type.measure_type_id,
          goods_nomenclature_item_id: goods_nomenclature.goods_nomenclature_item_id,
          geographical_area_sid: geographical_area.geographical_area_sid,
          additional_code_sid: additional_code.additional_code_sid,
          additional_code_type: additional_code_type,
          additional_code_id: additional_code.additional_code,
        )

        new_measure.validity_start_date = Date.current
        new_measure.validity_end_date = Date.current + 2.months

        new_measure.justification_regulation_id = "abc"
        new_measure.justification_regulation_role = 1

        expect(new_measure.additional_code).not_to be(nil)
        expect(new_measure).not_to be_conformant
        expect(new_measure.conformance_errors).to have_key(:ME32)
      end

      it "fails validation for test case 4" do
        # Case 4: When one period is inside of another period.
        # When existing measure validity start date is after new measure's
        # validity start date and existing measure's validity end date
        # is before new measure's validity end date

        _measure = create(
          :measure,
          measure_type_id: measure_type.measure_type_id,
          goods_nomenclature_item_id: goods_nomenclature.goods_nomenclature_item_id,
          geographical_area_sid: geographical_area.geographical_area_sid,
          additional_code_sid: additional_code.additional_code_sid,
          additional_code_type: additional_code_type,
          additional_code_id: additional_code.additional_code,
          validity_start_date: Date.current + 1.month,
          validity_end_date: Date.current + 2.months
        )

        new_measure = create(
          :measure,
          measure_type_id: measure_type.measure_type_id,
          goods_nomenclature_item_id: goods_nomenclature.goods_nomenclature_item_id,
          geographical_area_sid: geographical_area.geographical_area_sid,
          additional_code_sid: additional_code.additional_code_sid,
          additional_code_type: additional_code_type,
          additional_code_id: additional_code.additional_code,
        )

        new_measure.validity_start_date = Date.current
        new_measure.validity_end_date = Date.current + 5.months

        new_measure.justification_regulation_id = "abc"
        new_measure.justification_regulation_role = 1

        expect(new_measure.additional_code).not_to be(nil)
        expect(new_measure).not_to be_conformant
        expect(new_measure.conformance_errors).to have_key(:ME32)
      end
    end

    describe 'ME33' do
      let(:measure) {
        create :measure, justification_regulation_id: nil,
                                      justification_regulation_role: nil
      }

      context 'measure validity end date is set' do
        before { measure.validity_end_date = Date.today }

        it 'performs validation' do
          expect(measure).not_to be_conformant
        end
      end

      context 'measure validity end date is not set' do
        before { measure.validity_end_date = nil }

        it 'performs validation' do
          expect(measure).to be_conformant
        end
      end
    end

    describe 'ME29' do
      context 'generating modification regulation abrogated' do
        let(:measure) { create :measure, :with_abrogated_modification_regulation }

        it 'performs validation' do
          expect(measure).not_to be_conformant
        end
      end

      context 'generating regulation is not modification regulation' do
        let(:measure) { create :measure }

        it 'performs validation' do
          expect(measure).to be_conformant
        end
      end
    end

    describe 'ME34' do
      let(:measure) {
        create :measure, justification_regulation_id: 'abc',
                                      justification_regulation_role: 1
      }

      context 'measure validity end date is set' do
        before {
          measure.geographical_area.update(validity_end_date: Date.today.in(1.year))
          measure.measure_type.update(validity_end_date: Date.today.in(1.year))
          measure.goods_nomenclature.update(validity_end_date: Date.today.in(1.year))

          measure.validity_end_date = Date.today
        }

        it 'performs validation' do
          expect(measure).to be_conformant
        end
      end

      context 'measure validity end date is not set' do
        before { measure.validity_end_date = nil }

        it 'performs validation' do
          expect(measure).not_to be_conformant
        end
      end
    end

    describe 'ME39' do
      it { is_expected.to validate_validity_date_span.of(:measure_partial_temporary_stops) }
    end

    # describe 'ME40' do
    #   let!(:measure) { create :measure }

    #   it "should pass validation successfully if flag is 'not permitted'" do
    #     measure_type = measure.measure_type
    #     measure_type.measure_component_applicable_code = "2"
    #     measure_type.save

    #     expect(measure).to be_conformant
    #   end

    #   it "should pass validation successfully if flag is 'mandatory'" do
    #     measure_type = measure.measure_type
    #     measure_type.measure_component_applicable_code = "1"
    #     measure_type.save

    #     measure_component = create(:measure_component, measure_sid: measure.measure_sid)
    #     measure.reload
    #     expect(measure).to be_conformant

    #     measure_component.destroy

    #     measure.reload
    #     expect(measure.measure_components.size).to eq(0)

    #     measure_condition = create(:measure_condition, measure_sid: measure.measure_sid)
    #     create(:measure_condition_component, measure_condition_sid: measure_condition.measure_condition_sid)

    #     measure.reload
    #     expect(measure).to be_conformant
    #   end

    #   it "should not pass validation successfully if flag is 'not permitted'" do
    #     measure_type = measure.measure_type
    #     measure_type.measure_component_applicable_code = "2"
    #     measure_type.save

    #     create(:measure_component, measure_sid: measure.measure_sid)
    #     expect(measure.measure_components.size).to eq(1)

    #     measure_condition = create(:measure_condition, measure_sid: measure.measure_sid)
    #     _measure_condition_component = create(:measure_condition_component, measure_condition_sid: measure_condition.measure_condition_sid)

    #     expect(measure).to_not be_conformant
    #     expect(measure.conformance_errors).to have_key(:ME40)
    #   end

    #   it "should not pass validation successfully if flag is 'mandatory'" do
    #     measure_type = measure.measure_type
    #     measure_type.measure_component_applicable_code = "1"
    #     measure_type.save

    #     measure.reload

    #     expect(measure).to_not be_conformant
    #     expect(measure.conformance_errors).to have_key(:ME40)
    #   end
    # end

    describe 'ME86' do
      it { is_expected.to validate_inclusion.of(:measure_generating_regulation_role).in(Measure::VALID_ROLE_TYPE_IDS) }
    end

    describe 'ME88' do
      let(:measure1) {
        create :measure, type_explosion_level: 10,
                                        gono_number_indents: 1
      }
      let(:measure2) {
        create :measure, type_explosion_level: 1,
                                        gono_number_indents: 10
      }

      it 'preforms validation' do
        expect(measure1).to be_conformant
        expect(measure2).not_to be_conformant
      end
    end

    describe %(ME104 :The justification regulation must be either:
      - the measure’s measure-generating regulation, or
      - a measure-generating regulation, valid on the day after the measure’s (explicit) end date.
      If the measure’s measure-generating regulation is ‘approved’, then so must be the justification regulation) do

      let!(:base_regulation) { create :base_regulation }
      let!(:base_regulation2) { create :base_regulation }

      let!(:measure) do
        create(
          :measure,
          measure_generating_regulation_role: base_regulation.base_regulation_role,
          measure_generating_regulation_id: base_regulation.base_regulation_id,
          justification_regulation_role: base_regulation.base_regulation_role,
          justification_regulation_id: base_regulation.base_regulation_id,
          base_regulation: base_regulation,
          national: true
        )
      end

      describe "SUCCESS CASES" do
        describe "CASE 1" do
          before do
            measure.validity_end_date = Date.today
            measure.save
          end

          it "runs validation successfull if measure's justfication regulation is generating regulation" do
            # CASE 1:
            # The justification regulation must be either the measure’s measure-generating regulation

            expect(measure).to be_conformant
          end
        end

        describe "CASE 2-1" do
          before do
            measure.justification_regulation_id = nil
            measure.justification_regulation_role = nil
            measure.save
          end

          it "runs validation successfull if measure's generating regulation valid on day after measure's end date" do
            # CASE 2-1:
            # OR measure-generating regulation should be valid on the day after the measure’s (explicit) end date.

            expect(measure).to be_conformant
          end
        end

        describe "CASE 2-2" do
          before do
            measure.justification_regulation_id = nil
            measure.justification_regulation_role = nil
            measure.validity_end_date = nil
            measure.save

            base_regulation.validity_end_date = nil
            base_regulation.save
          end

          it "runs validation successfull if measure's and generating regulation's validity end date is blank" do
            # CASE 2-2:

            expect(measure).to be_conformant
          end
        end

        describe "CASE 3" do
          before do
            measure.justification_regulation_id = base_regulation2.base_regulation_id
            measure.justification_regulation_role = base_regulation2.base_regulation_role
            measure.validity_end_date = Date.today
            measure.save

            base_regulation.validity_end_date = Date.today
            base_regulation.approved_flag = true
            base_regulation.save

            base_regulation2.approved_flag = true
            base_regulation2.approved_flag = true
            base_regulation2.save
          end

          it "runs validation successfull If the measure’s measure-generating regulation is ‘approved’, then so must be the justification regulation" do
            # CASE 3:
            # If the measure’s measure-generating regulation is ‘approved’, then so must be the justification regulation

            expect(measure).to be_conformant
          end
        end
      end

      describe "FAILURE CASES" do
        it "returns error ME104 if generating regulation vaidity end is before measure validity end date and generating regulation |= justification regulation" do
          measure.justification_regulation_id = base_regulation2.base_regulation_id
          measure.justification_regulation_role = base_regulation2.base_regulation_role
          measure.validity_end_date = Date.today
          measure.save

          base_regulation.validity_end_date = measure.validity_end_date - 1.day
          base_regulation.save

          expect(measure).not_to be_conformant
          expect(measure.conformance_errors).to have_key(:ME104)
        end

        it "returns error ME104 if generating regulation vaidity end is blank and measure validity end date is set" do
          measure.justification_regulation_id = base_regulation2.base_regulation_id
          measure.justification_regulation_role = base_regulation2.base_regulation_role
          measure.validity_end_date = Date.today
          measure.save

          base_regulation.validity_end_date = nil
          base_regulation.save

          expect(measure).not_to be_conformant
          expect(measure.conformance_errors).to have_key(:ME104)
        end

        it "returns error ME104 if measure justification regulation is different than generating regulation and one of them is false for approve flag" do
          measure.justification_regulation_id = base_regulation2.base_regulation_id
          measure.justification_regulation_role = base_regulation2.base_regulation_role
          measure.validity_end_date = Date.today
          measure.save

          base_regulation.validity_end_date = Date.today
          base_regulation.approved_flag = true
          base_regulation.save

          base_regulation2.approved_flag = false
          base_regulation2.save

          expect(measure).not_to be_conformant
          expect(measure.conformance_errors).to have_key(:ME104)
        end
      end
    end

    describe "ME112" do
      let!(:additional_code_type) {
        create(
          :additional_code_type,
          additional_code_type_id: "4",
          application_code: "4",
          validity_start_date: Date.yesterday
        )
      }

      let!(:measure) { create :measure, additional_code_type_id: additional_code_type.additional_code_type_id }

      it "If the additional code type has as application 'Export Refund for Processed Agricultural Goods' then the measure does not require a goods code." do
        expect(measure.goods_nomenclature_item_id).to be_truthy
        expect(measure).not_to be_conformant
        expect(measure.conformance_errors).to have_key(:ME112)
      end
    end

    describe "ME113" do
      let!(:additional_code_type) {
        create(
          :additional_code_type,
          additional_code_type_id: "4",
          application_code: "4",
          validity_start_date: Date.yesterday
        )
      }

      let!(:measure) { create :measure, additional_code_type_id: additional_code_type.additional_code_type_id }

      it "If the additional code type has as application 'Export Refund for Processed Agricultural Goods' then the additional code must exist as an Export Refund for Processed Agricultural Goods additional code." do
        expect(measure).not_to be_conformant
        expect(measure.conformance_errors).to have_key(:ME113)
      end
    end

    describe 'ME116' do
      it { is_expected.to validate_validity_date_span.of(:order_number) }
    end

    # describe "ME117" do
    #   describe "with quota measure type" do
    #     it "valid" do
    #       validity_start_date = Date.new(2008,1,1)
    #       measure = create :measure,
    #                        ordernumber: "090",
    #                        order_number_capture_code: 1,
    #                        validity_start_date: validity_start_date
    #       quota_order_number = create(
    #         :quota_order_number,
    #         quota_order_number_id: measure.ordernumber,
    #         validity_start_date: validity_start_date
    #       )
    #       quota_order_number_origin = create(
    #         :quota_order_number_origin,
    #         quota_order_number_sid: quota_order_number.quota_order_number_sid,
    #         validity_start_date: validity_start_date
    #       )
    #       expect(measure).to be_conformant
    #     end

    #     it "invalid" do
    #       validity_start_date = Date.new(2008,1,1)
    #       measure = create :measure,
    #                        ordernumber: "090",
    #                        order_number_capture_code: 1,
    #                        validity_start_date: validity_start_date
    #       quota_order_number = create(
    #         :quota_order_number,
    #         quota_order_number_id: measure.ordernumber,
    #         validity_start_date: validity_start_date
    #       )

    #       bindig.pry
    #       expect(measure).to_not be_conformant
    #       expect(measure.conformance_errors).to have_key(:ME117)
    #     end
    #   end

    #   it "ignore order numbers starting with 094" do
    #     validity_start_date = Date.new(2008,1,1)
    #     measure = create :measure,
    #                      ordernumber: "094",
    #                      order_number_capture_code: 1,
    #                      validity_start_date: validity_start_date
    #     quota_order_number = create(
    #       :quota_order_number,
    #       quota_order_number_id: measure.ordernumber,
    #       validity_start_date: validity_start_date
    #     )
    #     expect(measure).to be_conformant
    #   end
    # end

    describe "ME118" do
      describe "with quota number" do
        it "valid" do
          validity_start_date = Date.new(2008, 1, 1)
          measure = create :measure,
            ordernumber: "090",
            order_number_capture_code: 1,
            validity_start_date: validity_start_date
          quota_order_number = create(
            :quota_order_number,
            quota_order_number_id: measure.ordernumber,
            validity_start_date: validity_start_date
          )
          quota_order_number_origin = create(
            :quota_order_number_origin,
            quota_order_number_sid: quota_order_number.quota_order_number_sid,
            validity_start_date: validity_start_date
          )

          expect(measure).to be_conformant
        end

        it "invalid" do
          validity_start_date = Date.new(2008, 1, 1)
          measure = create :measure,
            ordernumber: "090",
            order_number_capture_code: 1,
            validity_start_date: validity_start_date
          quota_order_number = create(
            :quota_order_number,
            quota_order_number_id: measure.ordernumber,
            validity_start_date: Date.new(2008, 1, 2)
          )
          expect(measure).not_to be_conformant
          expect(measure.conformance_errors).to have_key(:ME118)
        end
      end
    end

    describe "ME119", :pending do
      describe "with quota number origin" do
        it "valid" do
          validity_start_date = Date.new(2008, 1, 1)
          measure = create :measure,
            ordernumber: "090",
            order_number_capture_code: 1,
            validity_start_date: validity_start_date
          quota_order_number = create(
            :quota_order_number,
            quota_order_number_id: measure.ordernumber,
            validity_start_date: validity_start_date
          )
          quota_order_number_origin = create(
            :quota_order_number_origin,
            quota_order_number_sid: quota_order_number.quota_order_number_sid,
            validity_start_date: validity_start_date
          )

          expect(measure).to be_conformant

          pending("Rule commented out in c40a8679")
          fail
        end

        it "invalid" do
          validity_start_date = Date.new(2008, 1, 1)
          measure = create :measure,
            ordernumber: "090",
            order_number_capture_code: 1,
            validity_start_date: validity_start_date
          quota_order_number = create(
            :quota_order_number,
            quota_order_number_id: measure.ordernumber,
            validity_start_date: Date.new(2008, 1, 2)
          )
          quota_order_number_origin = create(
            :quota_order_number_origin,
            quota_order_number_sid: quota_order_number.quota_order_number_sid,
            validity_start_date: Date.new(2008, 1, 2)
          )
          expect(measure).not_to be_conformant
          expect(measure.conformance_errors).to have_key(:ME119)
        end
      end
    end
  end

  describe '#origin' do
    before(:all) { described_class.unrestrict_primary_key }

    it 'is uk' do
      expect(described_class.new(measure_sid: -1).origin).to eq "uk"
    end
    it 'is eu' do
      expect(described_class.new(measure_sid: 1).origin).to eq "eu"
    end
  end

  describe "#measure_generating_regulation_id" do
    it 'reads measure generating regulation id from database' do
      measure = create :measure
      expect(measure.measure_generating_regulation_id).not_to be_blank
      expect(measure.measure_generating_regulation_id).to eq described_class.first.measure_generating_regulation_id
    end

    it 'measure D9500019 is globally replaced with D9601421' do
      measure = create :measure, measure_generating_regulation_id: "D9500019"
      expect(measure.measure_generating_regulation_id).not_to be_blank
      expect(measure.measure_generating_regulation_id).to eq "D9601421"
    end
  end

  describe "#order_number" do
    context "quota_order_number associated" do
      let(:quota_order_number) { create :quota_order_number }
      let(:measure) { create :measure, ordernumber: quota_order_number.quota_order_number_id }

      it 'returns associated quota order nmber' do
        expect(measure.order_number).to eq quota_order_number
      end
    end

    context "quota_order_number missing" do
      let(:ordernumber) { 6.times.map { Random.rand(9) }.join }
      let(:measure) { create :measure, ordernumber: ordernumber }

      it 'returns a mock quota order number with just the number set' do
        expect(measure.order_number.quota_order_number_id).to eq ordernumber
      end

      it 'associated mock quota order number should have no quota definition' do
        expect(measure.order_number.quota_definition).to be_blank
      end
    end
  end

  describe "#import" do
    let(:measure) { create :measure, measure_type: measure_type }

    context 'measure type is import' do
      let(:measure_type) { create :measure_type, :import }

      it 'returns true' do
        expect(measure.import).to be_truthy
      end
    end

    context 'measure type is export' do
      let(:measure_type) { create :measure_type, :export }

      it 'returns false' do
        expect(measure.import).to be_falsy
      end
    end
  end

  describe "#export" do
    let(:measure) { create :measure, measure_type: measure_type }

    context 'measure type is import' do
      let(:measure_type) { create :measure_type, :import }

      it 'returns false' do
        expect(measure.export).to be_falsy
      end
    end

    context 'measure type is export' do
      let(:measure_type) { create :measure_type, :export }

      it 'returns true' do
        expect(measure.export).to be_truthy
      end
    end
  end

  describe '#generating_regulation_code' do
    let(:measure) {
      build :measure,
      measure_generating_regulation_id: '1234567'
    }

    it 'returns generating regulation code in TARIC format' do
      expect(measure.generating_regulation_code).to eq '14567/23'
    end
  end

  describe '#generating_regulation_url' do
    context "for base_regulation" do
      context "for Official Journal - C (Information and Notices) seria" do
        let!(:base_regulation) do
          create(:base_regulation, base_regulation_id: "I1703530",
                                   base_regulation_role: 1,
                                   published_date: Date.new(2017, 10, 20),
                                   officialjournal_number: "C 353",
                                   officialjournal_page: 19)
        end

        let!(:measure) do
          create(:measure, goods_nomenclature_item_id: "8711601000",
                           measure_generating_regulation_id: "I1703530",
                           base_regulation: base_regulation)
        end

        before do
          measure.reload
        end

        it "generates council regulation url" do
          expect(measure.generating_regulation_url).to be_eql("http://eur-lex.europa.eu/search.html?whOJ=NO_OJ%3D353,YEAR_OJ%3D2017,PAGE_FIRST%3D0019&DB_COLL_OJ=oj-c&type=advanced&lang=en")
        end
      end

      context "for Official Journal - L (Legislation) seria" do
        let!(:base_regulation) do
          create(:base_regulation, base_regulation_id: "R1708920",
                                   base_regulation_role: 1,
                                   published_date: Date.new(2017, 0o5, 25),
                                   officialjournal_number: "L 138",
                                   officialjournal_page: 57)
        end

        let!(:measure) do
          create(:measure, goods_nomenclature_item_id: "0808108000",
                           measure_generating_regulation_id: "R1708920",
                           base_regulation: base_regulation)
        end

        before do
          measure.reload
        end

        it "generates council regulation url" do
          expect(measure.generating_regulation_url).to be_eql("http://eur-lex.europa.eu/search.html?whOJ=NO_OJ%3D138,YEAR_OJ%3D2017,PAGE_FIRST%3D0057&DB_COLL_OJ=oj-l&type=advanced&lang=en")
        end
      end
    end

    context "for suspending_regulation" do
      context "for FullTemporaryStopRegulation" do
        let!(:fts_regulation) do
          create(:fts_regulation, full_temporary_stop_regulation_id: "R9528150",
                                  full_temporary_stop_regulation_role: 8,
                                  published_date: Date.new(1995, 12, 9),
                                  officialjournal_number: "L 297",
                                  officialjournal_page: 1)
        end

        let!(:measure) do
          create(:measure, goods_nomenclature_item_id: "0100000000",
                           measure_generating_regulation_id: "R9309900")
        end

        let!(:fts_regulation_action) do
          create(:fts_regulation_action, fts_regulation_role: 8,
                                         fts_regulation_id: "R9528150",
                                         stopped_regulation_role: 1,
                                         stopped_regulation_id: "R9309900")
        end

        before do
          measure.reload
        end

        it "generates council regulation url" do
          expect(measure.generating_regulation_url(true)).to be_eql(
            "http://eur-lex.europa.eu/search.html?whOJ=NO_OJ%3D297,YEAR_OJ%3D1995,PAGE_FIRST%3D0001&DB_COLL_OJ=oj-l&type=advanced&lang=en"
          )
        end
      end

      context "for MeasurePartialTemporaryStop" do
        let!(:base_regulation) do
          create(:base_regulation, base_regulation_id: "R0912150",
                                   base_regulation_role: 1,
                                   published_date: Date.new(2009, 12, 15),
                                   officialjournal_number: "L 328",
                                   officialjournal_page: 1)
        end

        let!(:measure) do
          create(:measure, goods_nomenclature_item_id: "2823000000",
                           measure_generating_regulation_id: "R0912150",
                           base_regulation: base_regulation)
        end

        let!(:measure_partial_temporary_stop) do
          create(:measure_partial_temporary_stop, measure_sid: measure.measure_sid,
                                                  partial_temporary_stop_regulation_id: "R0912150",
                                                  validity_start_date: DateTime.parse("2010-01-04T00:00:00.000Z"),
                                                  officialjournal_number: "L 328",
                                                  officialjournal_page: 6)
        end

        before do
          measure.reload
        end

        it "generates council regulation url" do
          expect(measure.generating_regulation_url(true)).to be_eql(
            "http://eur-lex.europa.eu/search.html?whOJ=NO_OJ%3D328,PAGE_FIRST%3D0006&DB_COLL_OJ=oj-l&type=advanced&lang=en"
          )
        end
      end
    end
  end

  describe '#meursing?' do
    let(:measure) { create :measure }

    context 'any measure components are meursing' do
      let!(:measure_component) {
        create :measure_component,
          measure_sid: measure.measure_sid,
          duty_expression_id: DutyExpression::MEURSING_DUTY_EXPRESSION_IDS.sample
      }

      it 'returns true' do
        expect(measure).to be_meursing
      end
    end

    context 'no measure components are meursing' do
      let!(:measure_component) {
        create :measure_component,
          measure_sid: measure.measure_sid,
          duty_expression_id: 'aaa'
      }

      it 'returns false' do
        expect(measure).not_to be_meursing
      end
    end
  end

  describe '#national_measurement_units_for' do
    let(:measure_type) { create :measure_type, measure_type_description: measure_type_description }
    let(:measure) { create :measure, measure_type_id: measure_type.measure_type_id }

    context 'measure is excise' do
      let(:measure_type_description) { 'EXCISE 111' }

      context 'declarable is passed in' do
        let(:commodity) { create :commodity }

        context 'declarable has national measurement unit set associated' do
          let(:tbl1) { create :tbl9, :unoq }
          let(:tbl2) { create :tbl9, :unoq }
          let!(:comm1) {
            create :comm, cmdty_code: commodity.goods_nomenclature_item_id,
                                      fe_tsmp: Date.today.ago(2.years),
                                      le_tsmp: nil,
                                      uoq_code_cdu2: tbl1.tbl_code,
                                      uoq_code_cdu3: tbl2.tbl_code
          }

          it 'returns national measurement unit names as a string array' do
            expect(measure.national_measurement_units_for(commodity).join).to match /#{Regexp.escape(tbl1.tbl_txt)}/i
            expect(measure.national_measurement_units_for(commodity).join).to match /#{Regexp.escape(tbl2.tbl_txt)}/i
          end
        end

        context 'declarable does not have national measurement unit set associated' do
          it 'returns blank result' do
            expect(measure.national_measurement_units_for(commodity)).to be_blank
          end
        end
      end

      context 'declarable is blank' do
        it 'returns blank result' do
          expect(measure.national_measurement_units_for(nil)).to be_blank
        end
      end
    end

    context 'measure is not excise' do
      let(:measure_type_description) { create :measure_type_description, description: 'not really e_x_c_i_s_e' }
      let(:measure_type) { create :measure_type, measure_type_id: measure_type_description.measure_type_id, measure_type_description: measure_type_description }
      let(:measure) { create :measure, measure_type_id: measure_type.measure_type_id }

      it 'returns blank result' do
        expect(measure.national_measurement_units_for(nil)).to be_blank
      end
    end
  end

  describe '.changes_for' do
    context 'measure validity start date lower than requested date' do
      it 'incudes measure' do
        create :measure, validity_start_date: Date.new(2014, 2, 1)
        TimeMachine.at(Date.new(2014, 1, 30)) do
          expect(described_class.changes_for).to be_empty
        end
      end
    end

    context 'measure validity start date higher than requested date' do
      it 'does not include measure' do
        measure = create :measure, validity_start_date: Date.new(2014, 2, 1)
        TimeMachine.at(Date.new(2014, 2, 1)) do
          expect(described_class.changes_for).not_to be_empty
          expect(described_class.changes_for.first.oid).to eq measure.source.oid
        end
      end

      it 'returns records with NULL operation_date last' do
        create :measure, validity_start_date: Date.new(2014, 2, 1), operation_date: Date.new(2014, 2, 1)
        create :measure, validity_start_date: Date.new(2014, 2, 1)
        TimeMachine.at(Date.new(2014, 2, 1)) do
          changes_for = described_class.changes_for
          expect(changes_for.count).to eq(2)
          expect(changes_for.first.operation_date).to be_truthy
          expect(changes_for.last.operation_date).to be_falsey
        end
      end
    end
  end

  describe "#duty_expression_with_national_measurement_units_for ^ #formatted_duty_expression_with_national_measurement_units_for" do
    let(:commodity) {
      create :commodity
    }
    let(:base) {
      measure.duty_expression_with_national_measurement_units_for(commodity)
    }
    let(:formatted_base) {
      measure.formatted_duty_expression_with_national_measurement_units_for(commodity)
    }
    let(:measure_type) {
      create :measure_type, :excise
    }
    let(:measure) {
      create :measure, measure_type_id: measure_type.measure_type_id
    }
    let(:duty_expression) {
      create(:duty_expression, :with_description)
    }
    let!(:measure_component) {
      create :measure_component, measure_sid: measure.measure_sid,
                                 duty_expression_id: duty_expression.duty_expression_id
    }

    context "without national_measurement_unit" do
      it {
        expect(base).to match Regexp.new(measure_component.duty_expression_str)
      }
      it {
        expect(formatted_base).to match Regexp.new(measure_component.formatted_duty_expression)
      }
    end

    context "with national_measurement_unit" do
      let!(:comm1) {
        create :comm, cmdty_code: commodity.goods_nomenclature_item_id,
                                   fe_tsmp: Date.today.ago(2.years),
                                   le_tsmp: nil,
                                   uoq_code_cdu2: tbl1.tbl_code,
                                   uoq_code_cdu3: tbl2.tbl_code
      }
      let(:tbl1) { create :tbl9, :unoq, tbl_code: 'aa1' }
      let(:tbl2) { create :tbl9, :unoq, tbl_code: 'aa2' }

      let(:national_measurement_units) {
        measure.national_measurement_units_for(commodity)
      }

      it {
        expect(base).to match Regexp.new(measure_component.duty_expression_str)
        national_measurement_units.each do |unit|
          expect(base).to match Regexp.new(unit)
        end
      }
      it {
        expect(formatted_base).to match Regexp.new(measure_component.formatted_duty_expression)
        national_measurement_units.each do |unit|
          expect(formatted_base).to match Regexp.new(unit)
        end
      }
    end
  end
end

describe Measure, "#set_searchable_data!" do
  it "refreshes the searchable data without inserting oplog rows" do
    measure = create(:measure, searchable_data: nil)

    expect { measure.set_searchable_data! }.
      not_to change { oplog_count_for_measure(measure) }.from(1)
  end

  it "refreshes the searchable data without updating other columns" do
    measure = create(:measure, searchable_data: nil, national: true)

    expect(measure.searchable_data).not_to be_present
    expect(measure.searchable_data_updated_at).not_to be_present

    # Modify an attribute unrelated to searchable data
    measure.national = false
    measure.set_searchable_data!

    measure_oplog =
      Measure::Operation.where(measure_sid: measure.measure_sid).last

    expect(measure_oplog.searchable_data).to be_present
    expect(measure_oplog.searchable_data_updated_at).to be_present
    expect(measure_oplog.national).to eq true
  end

  private

  def oplog_count_for_measure(measure)
    Measure::Operation.where(measure_sid: measure.measure_sid).count
  end
end
