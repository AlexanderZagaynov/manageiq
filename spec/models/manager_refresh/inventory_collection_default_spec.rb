# frozen_string_literal: true

describe ManagerRefresh::InventoryCollectionDefault do
  it 'pickups existing Vm and MiqTemplate records on Amazon EMS re-adding' do
    ems = new_amazon_ems

    with_vcr_data { expect { EmsRefresh.refresh(ems) }.to change { VmOrTemplate.count }.from(0) }
    expect { ems.destroy }.to_not change { VmOrTemplate.count }

    aggregate_failures do
      expect(Vm.count).to_not be_zero
      expect(MiqTemplate.count).to_not be_zero
      expect(ExtManagementSystem.count).to be_zero
    end

    ems = new_amazon_ems

    with_vcr_data do
      expect { EmsRefresh.refresh(ems) }
        .to  change { VmOrTemplate.distinct.pluck(:ems_id) }.from([nil]).to([ems.id])
        .and change { VmOrTemplate.count } .by(0)
        .and change { MiqTemplate.count }  .by(0)
        .and change { Vm.count }           .by(0)
    end
  end

  # TODO (zalex): remove whole context on the further described_class development
  context 'refactoring' do
    OLD_VERSION_URL = 'https://raw.githubusercontent.com/ManageIQ/manageiq/8696169931b6b6c184ac21022162e99b3e21d236/app/models/manager_refresh/inventory_collection_default.rb'

    before :context do
      described_class_name = described_class.name.demodulize
      described_class_parent = described_class.parent

      @new_version = described_class_parent.const_get(described_class_name)
      described_class_parent.send(:remove_const, described_class_name)

      old_version_file = Tempfile.new(['', '.rb'])
      with_vcr_data do
        old_version_file << Net::HTTP.get(URI OLD_VERSION_URL)
      end
      old_version_file.flush
      load old_version_file.path
      old_version_file.close!

      @old_version = described_class_parent.const_get(described_class_name)
      described_class_parent.send(:remove_const, described_class_name)
      described_class_parent.const_set(described_class_name, @new_version)

      @old_methods = @old_version.methods(false)
      @new_methods = @new_version.methods(false)
    end

    shared_examples :unchanged do |method_name, *args|
      it "#{method_name}: #{args.inspect}" do
        new_result = cleanup_result_data @new_version.public_send(method_name, *args)
        old_result = cleanup_result_data @old_version.public_send(method_name, *args)
        expect(new_result).to eq(old_result)
      end
    end

    it { expect(@new_methods).to eq(@old_methods) }

    described_class.methods(false).each do |method_name|
      it_should_behave_like :unchanged, method_name
    end

    it_should_behave_like :unchanged, :disks, :strategy => :local_db_cache_all

    private

    def cleanup_result_data(hash_object)
      hash_object.each do |key, value|
        hash_object[key] =
          case value
          when Hash
            cleanup_result_data(value.dup)
          when Array
            value.sort
          when Module
            value.name
          when Proc
            'Proc'
          else
            value
          end
      end
    end

    def with_vcr_data
      cassette_file_name = "#{described_class.name.underscore}-refactoring"
      VCR.use_cassette(cassette_file_name) { yield }
    end
  end

  private

  def with_vcr_data
    cassette_file_name = described_class.name.underscore
    VCR.use_cassette(cassette_file_name) { yield }
  end

  def new_amazon_ems
    FactoryGirl.create(:ems_amazon_with_vcr_authentication, :provider_region => 'eu-central-1')
  end
end
