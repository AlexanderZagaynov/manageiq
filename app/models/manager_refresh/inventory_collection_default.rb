# frozen_string_literal: true

class ManagerRefresh::InventoryCollectionDefault
  ATTRIBUTES_CONST_REGEXP = /_ATTRIBUTES$/i

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

    :targeted_arel                => lambda do |inventory_collection|
      manager_uuids = inventory_collection.parent_inventory_collections.flat_map { |c| c.manager_uuids.to_a }
      inventory_collection.parent.disks.joins(:hardware => :vm_or_template)
        .where(:hardware => { 'vms' => { :ems_ref => manager_uuids } })
    end.freeze,
  }.freeze

  class << self
    private

    def define_attribute_getters
      constants(false).grep(ATTRIBUTES_CONST_REGEXP).each do |const_name|
        method_name = const_name.to_s.sub(ATTRIBUTES_CONST_REGEXP, '').underscore.pluralize.to_sym
        next if singleton_class.method_defined?(method_name)
        define_singleton_method method_name do |extra_attributes = {}|
          const_get(const_name).merge(extra_attributes)
        end
      end
    end
  end

  define_attribute_getters
end
