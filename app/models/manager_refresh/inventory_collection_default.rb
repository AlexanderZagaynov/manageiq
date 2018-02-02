# frozen_string_literal: true

class ManagerRefresh::InventoryCollectionDefault
  INVENTORY_RECONNECT_BLOCK = lambda do |inventory_collection, inventory_objects_index, attributes_index|
    relation = inventory_collection.model_class.where(:ems_id => nil)

    return if relation.count <= 0

    inventory_objects_index.each_slice(100) do |batch|
      batch_refs = batch.map(&:first)
      relation.where(inventory_collection.manager_ref.first => batch_refs).each do |record|
        index = inventory_collection.object_index_with_keys(inventory_collection.manager_ref_to_cols, record)

        # We need to delete the record from the inventory_objects_index
        # and attributes_index, otherwise it would be sent for create.
        inventory_object = inventory_objects_index.delete(index)
        hash             = attributes_index.delete(index)

        record.assign_attributes(hash.except(:id, :type))
        if !inventory_collection.check_changed? || record.changed?
          record.save!
          inventory_collection.store_updated_records(record)
        end

        inventory_object.id = record.id
      end
    end
  end.freeze

  VM_ATTRIBUTES = {
    :model_class                 => ::Vm,
    :association                 => :vms,
    :use_ar_object               => true, # Because of raw_power_state setter and hooks are needed for settings user
    :delete_method               => :disconnect_inv,
    :saver_strategy              => :default,
    :attributes_blacklist        => %i[genealogy_parent].freeze,
    :custom_reconnect_block      => self::INVENTORY_RECONNECT_BLOCK,

    # TODO(lsmola) can't do batch strategy for vms because of key_pairs relation
    :batch_extra_attributes      => %i[
      power_state
      previous_state
      state_changed_on
    ].freeze,

    :inventory_object_attributes => %i[
      type
      cpu_limit
      cpu_reserve
      cpu_reserve_expand
      cpu_shares
      cpu_shares_level
      ems_ref
      ems_ref_obj
      uid_ems
      connection_state
      vendor
      name
      location
      template
      memory_limit
      memory_reserve
      memory_reserve_expand
      memory_shares
      memory_shares_level
      raw_power_state
      boot_time
      host
      ems_cluster
      storages
      storage
      snapshots
    ].freeze,

    :builder_params              => {
      :ems_id   => ->(persister) { persister.manager.id },
      :name     => "unknown",
      :location => "unknown",
    }.freeze,
  }.freeze

  MIQ_TEMPLATE_ATTRIBUTES = {
    :model_class                 => ::MiqTemplate,
    :association                 => :miq_templates,
    :use_ar_object               => true, # Because of raw_power_state setter
    :delete_method               => :disconnect_inv,
    :saver_strategy              => :default, # Hooks are needed for setting user
    :attributes_blacklist        => %i[genealogy_parent].freeze,
    :custom_reconnect_block      => self::INVENTORY_RECONNECT_BLOCK,

    :batch_extra_attributes      => %i[
      power_state
      previous_state
      state_changed_on
    ].freeze,

    :inventory_object_attributes => %i[
      type
      ems_ref
      ems_ref_obj
      uid_ems
      connection_state
      vendor
      name
      location
      template
      memory_limit
      memory_reserve
      raw_power_state
      boot_time
      host
      ems_cluster
      storages
      storage
      snapshots
    ].freeze,

    :builder_params              => {
      :ems_id   => ->(persister) { persister.manager.id },
      :name     => "unknown",
      :location => "unknown",
      :template => true,
    }.freeze,
  }.freeze

  HARDWARE_ATTRIBUTES = {
    :model_class                  => ::Hardware,
    :association                  => :hardwares,
    :manager_ref                  => %i[vm_or_template].freeze,
    # TODO(lsmola) just because of default value on cpu_sockets,
    # this can be fixed by separating instances_hardwares and images_hardwares
    :use_ar_object                => true,
    :parent_inventory_collections => %i[vms miq_templates].freeze,

    :inventory_object_attributes  => %i[
      annotation
      cpu_cores_per_socket
      cpu_sockets
      cpu_speed
      cpu_total_cores
      cpu_type
      guest_os
      manufacturer
      memory_mb
      model
      networks
      number_of_nics
      serial_number
      virtual_hw_version
    ].freeze,

    :custom_manager_uuid          => lambda do |hardware|
      [hardware.vm_or_template.ems_ref].freeze
    end.freeze,

    :custom_db_finder             => lambda do |inventory_collection, selection, _projection|
      relation = inventory_collection.parent.send(inventory_collection.association)
                                     .includes(:vm_or_template).references(:vm_or_template)
      if selection.present?
        ems_refs = selection.map { |x| x[:vm_or_template] }
        relation = relation.where(:vms => { :ems_ref => ems_refs })
      end
      relation
    end.freeze,

    :targeted_arel                => lambda do |inventory_collection|
      manager_uuids = inventory_collection.parent_inventory_collections.flat_map { |c| c.manager_uuids.to_a }
      inventory_collection.parent.hardwares.joins(:vm_or_template).where('vms' => { :ems_ref => manager_uuids })
    end.freeze,
  }.freeze

  OPERATING_SYSTEM_ATTRIBUTES = {
    :model_class                  => ::OperatingSystem,
    :association                  => :operating_systems,
    :manager_ref                  => %i[vm_or_template].freeze,
    :parent_inventory_collections => %i[vms miq_templates].freeze,

    :inventory_object_attributes  => %i[
      name
      product_name
      product_type
      system_type
      version
    ].freeze,

    :targeted_arel                => lambda do |inventory_collection|
      manager_uuids = inventory_collection.parent_inventory_collections.flat_map { |c| c.manager_uuids.to_a }
      inventory_collection.parent.operating_systems.joins(:vm_or_template)
        .where('vms' => { :ems_ref => manager_uuids })
    end.freeze,
  }.freeze

  DISK_ATTRIBUTES = {
    :model_class                  => ::Disk,
    :association                  => :disks,
    :manager_ref                  => %i[hardware device_name].freeze,
    :parent_inventory_collections => %i[vms].freeze,

    :inventory_object_attributes  => %i[
      device_name
      device_type
      controller_type
      present
      filename
      location
      size
      size_on_disk
      disk_type
      mode
      bootable
      storage
    ].freeze,

    :custom_manager_uuid          => lambda do |disk|
      [disk.hardware.vm_or_template.ems_ref, disk.device_name].freeze
    end.freeze,

    :targeted_arel                => lambda do |inventory_collection|
      manager_uuids = inventory_collection.parent_inventory_collections.flat_map { |c| c.manager_uuids.to_a }
      inventory_collection.parent.disks.joins(:hardware => :vm_or_template)
        .where(:hardware => { 'vms' => { :ems_ref => manager_uuids } })
    end.freeze,
  }.freeze

  class << self
    def vms(extra_attributes = {})
      self::VM_ATTRIBUTES.merge(extra_attributes)
    end

    def miq_templates(extra_attributes = {})
      self::MIQ_TEMPLATE_ATTRIBUTES.merge(extra_attributes)
    end

    def hardwares(extra_attributes = {})
      self::HARDWARE_ATTRIBUTES.merge(extra_attributes)
    end

    def operating_systems(extra_attributes = {})
      self::OPERATING_SYSTEM_ATTRIBUTES.merge(extra_attributes)
    end

    def disks(extra_attributes = {})
      attributes = self::DISK_ATTRIBUTES.merge(extra_attributes)
      if !extra_attributes.has_key?(:custom_manager_uuid) && extra_attributes[:strategy] != :local_db_cache_all
        attributes.delete(:custom_manager_uuid)
      end
      attributes
    end
  end
end
