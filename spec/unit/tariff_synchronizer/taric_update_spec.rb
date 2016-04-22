require "rails_helper"
require "tariff_synchronizer"

describe TariffSynchronizer::TaricUpdate do
  it_behaves_like "Base Update"

  let(:example_date) { Date.new(2010,1,1) }

  describe ".download" do
    let(:generator) { TaricFileNameGenerator.new(example_date) }

    it "Logs the request for the TaricUpdate file" do
      allow(TariffSynchronizer::TaricUpdate).to receive(:download_content)
        .with(generator.url).and_return(build(:response, :not_found))
      tariff_synchronizer_logger_listener
      TariffSynchronizer::TaricUpdate.download(example_date)
      expect(@logger.logged(:info).size).to eq 1
      expect(@logger.logged(:info).last).to eq("Checking for TARIC update for #{example_date} at #{generator.url}")
    end

    it "Calls the external server to download file" do
      expect(TariffSynchronizer::TaricUpdate).to receive(:download_content)
        .with(generator.url).and_return(build(:response, :not_found))
      TariffSynchronizer::TaricUpdate.download(example_date)
    end

    context "Successful Response" do
      before do
        allow(TariffSynchronizer::TaricUpdate).to receive(:download_content)
          .with(generator.url).and_return(build :response, :success, content: "ABC.xml\nXYZ.xml")
      end

      it "Calls TariffDownloader perform for each TARIC update file found" do
        downlader = instance_double("TariffSynchronizer::TariffDownloader", perform: true)

        ["ABC.xml", "XYZ.xml"].each do |filename|
          expect(TariffSynchronizer::TariffDownloader).to receive(:new)
            .with("2010-01-01_#{filename}", "http://example.com/taric/#{filename}", example_date, TariffSynchronizer::TaricUpdate)
            .and_return(downlader)
        end

        TariffSynchronizer::TaricUpdate.download(example_date)
      end
    end

    context "Missing Response" do
      before do
        allow(TariffSynchronizer::TaricUpdate).to receive(:download_content)
          .with(generator.url).and_return(build(:response, :not_found))
      end

      it "Creates a record with a missing state if the date has passed" do
        expect {
          TariffSynchronizer::TaricUpdate.download(example_date)
        }.to change(TariffSynchronizer::TaricUpdate, :count).by(1)

        taric_update = TariffSynchronizer::TaricUpdate.last
        expect(taric_update.filename).to eq("2010-01-01_taric")
        expect(taric_update.filesize).to be_nil
        expect(taric_update.issue_date).to eq(example_date)
        expect(taric_update.state).to eq(TariffSynchronizer::BaseUpdate::MISSING_STATE)
      end

      it "Doesn't create a record if the date is the same" do
        expect {
          travel_to example_date do
            TariffSynchronizer::TaricUpdate.download(example_date)
          end
        }.to_not change(TariffSynchronizer::TaricUpdate, :count)
      end

      it "Logs the creating of the TaricUpdate record with missing state" do
        tariff_synchronizer_logger_listener
        TariffSynchronizer::TaricUpdate.download(example_date)
        expect(@logger.logged(:warn).size).to eq 1
        expect(@logger.logged(:warn).last).to eq("Update not found for 2010-01-01 at http://example.com/taric/TARIC320100101")
      end
    end

    context "Retries Exceeded Response" do
      before do
        allow(TariffSynchronizer::TaricUpdate).to receive(:download_content)
          .with(generator.url).and_return(build(:response, :retry_exceeded))
      end

      it "Creates a record with a failed state" do
        expect {
          TariffSynchronizer::TaricUpdate.download(example_date)
        }.to change(TariffSynchronizer::TaricUpdate, :count).by(1)

        taric_update = TariffSynchronizer::TaricUpdate.last
        expect(taric_update.filename).to eq("2010-01-01_taric")
        expect(taric_update.filesize).to be_nil
        expect(taric_update.issue_date).to eq(example_date)
        expect(taric_update.state).to eq(TariffSynchronizer::BaseUpdate::FAILED_STATE)
      end

      it "Logs the creating of the TaricUpdate record with failed state" do
        tariff_synchronizer_logger_listener
        TariffSynchronizer::TaricUpdate.download(example_date)
        expect(@logger.logged(:warn).size).to eq 1
        expect(@logger.logged(:warn).last).to eq("Download retry count exceeded for http://example.com/taric/TARIC320100101")
      end

      it "Sends a warning email" do
        ActionMailer::Base.deliveries.clear
        TariffSynchronizer::TaricUpdate.download(example_date)
        email = ActionMailer::Base.deliveries.last
        expect(email.encoded).to match /Retry count exceeded/
      end
    end

    context "Blank Response" do
      before do
        allow(TariffSynchronizer::TaricUpdate).to receive(:download_content)
          .with(generator.url).and_return(build(:response, :blank))
      end

      it "Creates a record with a missing state" do
        expect {
          TariffSynchronizer::TaricUpdate.download(example_date)
        }.to change(TariffSynchronizer::TaricUpdate, :count).by(1)

        taric_update = TariffSynchronizer::TaricUpdate.last
        expect(taric_update.filename).to eq("2010-01-01_taric")
        expect(taric_update.filesize).to be_nil
        expect(taric_update.issue_date).to eq(example_date)
        expect(taric_update.state).to eq(TariffSynchronizer::BaseUpdate::FAILED_STATE)
      end

      it "Logs the creating of the TaricUpdate record with failed state" do
        tariff_synchronizer_logger_listener
        TariffSynchronizer::TaricUpdate.download(example_date)
        expect(@logger.logged(:error).size).to eq 1
        expect(@logger.logged(:error).last).to eq("Blank update content received for 2010-01-01: http://example.com/taric/TARIC320100101")
      end

      it "Sends a warning email" do
        ActionMailer::Base.deliveries.clear
        TariffSynchronizer::TaricUpdate.download(example_date)
        email = ActionMailer::Base.deliveries.last
        expect(email.encoded).to match /Received a blank file/
      end
    end
  end

  describe ".sync" do
    let(:not_found_response) { build :response, :not_found }

    it "notifies about several missing updates in a row" do
      allow(TariffSynchronizer::TaricUpdate).to receive(:download_content).and_return(not_found_response)
      expect(TariffSynchronizer::TaricUpdate).to receive(:notify_about_missing_updates)
      create :taric_update, :missing, issue_date: Date.today.ago(2.days)
      create :taric_update, :missing, issue_date: Date.today.ago(3.days)
      TariffSynchronizer::TaricUpdate.sync
    end

    it "Calls the difference from the intial update to the current time, the donwload method" do
      expect(TariffSynchronizer::TaricUpdate).to receive(:download_content).and_return(not_found_response).exactly(3).times
      travel_to TariffSynchronizer.taric_initial_update_date + 2 do
        TariffSynchronizer::TaricUpdate.sync
      end
    end
  end

  describe "#apply", truncation: true do
    let(:state) { :pending }

    before do
      create :taric_update, example_date: example_date
      prepare_synchronizer_folders
      create_taric_file example_date
    end

    it "executes Taric importer" do
      mock_importer = double("importer").as_null_object
      expect(TariffImporter).to receive(:new).and_return(mock_importer)

      TariffSynchronizer::TaricUpdate.first.apply
    end

    it "updates file entry state to processed" do
      mock_importer = double("importer").as_null_object
      expect(TariffImporter).to receive(:new).and_return(mock_importer)

      expect(TariffSynchronizer::TaricUpdate.pending.count).to eq 1
      TariffSynchronizer::TaricUpdate.first.apply
      expect(TariffSynchronizer::TaricUpdate.pending.count).to eq 0
      expect(TariffSynchronizer::TaricUpdate.applied.count).to eq 1
    end

    it "does not move file to processed if import fails" do
      mock_importer = double
      expect(mock_importer).to receive(:import).and_raise(TaricImporter::ImportException)
      expect(TariffImporter).to receive(:new).and_return(mock_importer)

      expect(TariffSynchronizer::TaricUpdate.pending.count).to eq 1

      expect { TariffSynchronizer::TaricUpdate.first.apply }.to raise_error Sequel::Rollback

      expect(TariffSynchronizer::TaricUpdate.pending.count).to eq 0
      expect(TariffSynchronizer::TaricUpdate.failed.count).to eq 1
      expect(TariffSynchronizer::TaricUpdate.applied.count).to eq 0
    end

    after  { purge_synchronizer_folders }
  end

  describe ".rebuild" do
    before do
      prepare_synchronizer_folders
      create_taric_file example_date
    end

    after { purge_synchronizer_folders }

    context "entry for the day/update does not exist yet" do
      it "creates db record from available file name" do
        expect(TariffSynchronizer::BaseUpdate.count).to eq 0

        TariffSynchronizer::TaricUpdate.rebuild

        expect(TariffSynchronizer::BaseUpdate.count).to eq 1
        first_update = TariffSynchronizer::BaseUpdate.first
        expect(first_update.issue_date).to eq example_date
      end
    end

    context "entry for the day/update exists already" do
      it "does not create db record if it is already available for the day/update type combo" do
        create :taric_update, example_date: example_date

        expect(TariffSynchronizer::BaseUpdate.count).to eq 1
        TariffSynchronizer::TaricUpdate.rebuild
        expect(TariffSynchronizer::BaseUpdate.count).to eq 1
      end
    end
  end

  describe "#import!" do

    let(:taric_update) { create :taric_update}

    before do
      # stub the file_path method to return a valid path of a real file.
      allow(taric_update).to receive(:file_path)
                              .and_return("spec/fixtures/taric_samples/insert_record.xml")

    end

    it "Calls the TaricImporter import method" do
      taric_importer = instance_double("TaricImporter")
      expect(TaricImporter).to receive(:new).with(taric_update.file_path,
                                                  taric_update.issue_date)
                                                  .and_return(taric_importer)
      expect(taric_importer).to receive(:import)
      taric_update.import!
    end

    it "Updates the filesize attribute of the Taric update" do
      allow_any_instance_of(TaricImporter).to receive(:import)
      taric_update.import!
      expect(taric_update.filesize).to eq(1553)
    end

    it "Mark the Taric update as applied" do
      allow_any_instance_of(TaricImporter).to receive(:import)
      taric_update.import!
      expect(taric_update.reload).to be_applied
    end

    it "logs an info event" do
      tariff_synchronizer_logger_listener
      allow_any_instance_of(TaricImporter).to receive(:import)
      taric_update.import!
      expect(@logger.logged(:info).size).to eq 1
      expect(@logger.logged(:info).last).to match /Applied TARIC update/
    end
  end
end
