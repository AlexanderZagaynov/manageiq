# frozen_string_literal: true

class ManagerRefresh::InventoryCollectionDefault::InfraManager < ManagerRefresh::InventoryCollectionDefault
  NETWORK_ATTRIBUTES = {
    :model_class                 => ::Network,
    :manager_ref                 => %i[hardware ipaddress ipv6address].freeze,
    :association                 => :networks,
    :inventory_object_attributes => %i[
      description
      hostname
      ipaddress
      subnet_mask
      ipv6address
    ].freeze,
  }.freeze

  HOST_NETWORK_ATTRIBUTES = {
    :model_class                 => ::Network,
    :manager_ref                 => %i[hardware ipaddress].freeze,
    :association                 => :host_networks,
    :inventory_object_attributes => %i[
      description
      hostname
      ipaddress
      subnet_mask
    ].freeze,
  }.freeze

  GUEST_DEVICE_ATTRIBUTES = {
    :model_class                 => ::GuestDevice,
    :manager_ref                 => %i[hardware uid_ems].freeze,
    :association                 => :guest_devices,
    :inventory_object_attributes => %i[
      address
      controller_type
      device_name
      device_type
      lan
      location
      network
      present
      switch
      uid_ems
    ].freeze,
  }.freeze

  HOST_HARDWARE_ATTRIBUTES = {
    :model_class                 => ::Hardware,
    :manager_ref                 => %i[host],
    :association                 => :host_hardwares,
    :inventory_object_attributes => %i[
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
    ].freeze,
  }.freeze

  SNAPSHOT_ATTRIBUTES = {
    :model_class                 => ::Snapshot,
    :manager_ref                 => %i[uid].freeze,
    :association                 => :snapshots,
    :inventory_object_attributes => %i[
      uid_ems
      uid
      parent_uid
      name
      description
      create_time
      current
      vm_or_template
    ].freeze,
  }.freeze

  OPERATING_SYSTEM_ATTRIBUTES = {
    :model_class                 => ::OperatingSystem,
    :manager_ref                 => %i[vm_or_template].freeze,
    :association                 => :operating_systems,
    :inventory_object_attributes => %i[
      name
      product_name
      product_type
      system_type
      version
    ].freeze,
  }.freeze

  HOST_OPERATING_SYSTEM_ATTRIBUTES = {
    :model_class                 => ::OperatingSystem,
    :manager_ref                 => %i[host].freeze,
    :association                 => :host_operating_systems,
    :inventory_object_attributes => %i[
      name
      product_name
      product_type
      system_type
      version
    ].freeze,
  }.freeze

  CUSTOM_ATTRIBUTE_ATTRIBUTES = {
    :model_class                 => ::CustomAttribute,
    :manager_ref                 => %i[name].freeze,
    :association                 => :custom_attributes,
    :inventory_object_attributes => %i[
      section
      name
      value
      source
    ].freeze,
  }.freeze

  EMS_FOLDER_ATTRIBUTES = {
    :model_class                 => ::EmsFolder,
    :association                 => :ems_folders,
    :manager_ref                 => %i[uid_ems].freeze,
    :attributes_blacklist        => %i[ems_children].freeze,
    :inventory_object_attributes => %i[
      ems_ref
      name
      type
      uid_ems
      hidden
    ].freeze,
    :builder_params              => {
      :ems_id => ->(persister) { persister.manager.id },
    }.freeze,
  }.freeze

  DATACENTER_ATTRIBUTES = {
    :model_class                 => ::Datacenter,
    :association                 => :datacenters,
    :inventory_object_attributes => %i[
      name
      type
      uid_ems
      ems_ref
      ems_ref_obj
      hidden
    ].freeze,
    :builder_params              => {
      :ems_id => ->(persister) { persister.manager.id },
    }.freeze,
  }.freeze

  RESOURCE_POOL_ATTRIBUTES = {
    :model_class                 => ::ResourcePool,
    :association                 => :resource_pools,
    :manager_ref                 => %i[uid_ems].freeze,
    :attributes_blacklist        => %i[ems_children].freeze,
    :inventory_object_attributes => %i[
      ems_ref
      name
      uid_ems
      is_default
    ].freeze,
    :builder_params              => {
      :ems_id => ->(persister) { persister.manager.id },
    }.freeze,
  }.freeze

  EMS_CLUSTER_ATTRIBUTES = {
    :model_class                 => ::EmsCluster,
    :association                 => :ems_clusters,
    :attributes_blacklist        => %i[ems_children datacenter_id].freeze,
    :inventory_object_attributes => %i[
      ems_ref
      ems_ref_obj
      uid_ems
      name
      datacenter_id
    ].freeze,
    :builder_params              => {
      :ems_id => ->(persister) { persister.manager.id },
    }.freeze,
  }.freeze

  STORAGE_ATTRIBUTES = {
    :model_class                 => ::Storage,
    :manager_ref                 => %i[location].freeze,
    :association                 => :storages,
    :complete                    => false,
    :arel                        => Storage,
    :inventory_object_attributes => %i[
      ems_ref
      ems_ref_obj
      name
      store_type
      storage_domain_type
      total_space
      free_space
      uncommitted
      multiplehostaccess
      location
      master
    ].freeze,
  }.freeze

  HOST_ATTRIBUTES = {
    :model_class                 => ::Host,
    :association                 => :hosts,
    :custom_reconnect_block      => self::INVENTORY_RECONNECT_BLOCK,
    :inventory_object_attributes => %i[
      type
      ems_ref
      ems_ref_obj
      name
      hostname
      ipaddress
      uid_ems
      vmm_vendor
      vmm_product
      vmm_version
      vmm_buildnumber
      connection_state
      power_state
      ems_cluster
      ipmi_address
      maintenance
    ].freeze,
    :builder_params              => {
      :ems_id => ->(persister) { persister.manager.id },
    }.freeze,
  }.freeze

  HOST_STORAGE_ATTRIBUTES = {
    :model_class                 => ::HostStorage,
    :manager_ref                 => %i[host storage].freeze,
    :association                 => :host_storages,
    :inventory_object_attributes => %i[
      ems_ref
      read_only
      host
      storage
    ].freeze,
  }.freeze

  HOST_SWITCH_ATTRIBUTES = {
    :model_class                 => ::HostSwitch,
    :manager_ref                 => %i[host switch].freeze,
    :association                 => :host_switches,
    :inventory_object_attributes => %i[
      host
      switch
    ].freeze,
  }.freeze

  SWITCH_ATTRIBUTES = {
    :model_class                 => ::Switch,
    :manager_ref                 => %i[uid_ems].freeze,
    :association                 => :switches,
    :inventory_object_attributes => %i[
      uid_ems
      name
      lans
    ].freeze,
  }.freeze

  LAN_ATTRIBUTES = {
    :model_class                 => ::Lan,
    :manager_ref                 => %i[uid_ems],
    :association                 => :lans,
    :inventory_object_attributes => %i[
      name
      uid_ems
      tag
    ].freeze,
  }.freeze

  SNAPSHOT_PARENT_ATTRIBUTES = {
    :association       => :snapshot_parent,
    :custom_save_block => lambda do |_ems, inventory_collection|
      snapshot_collection = inventory_collection.dependency_attributes[:snapshots].try(:first)
      snapshot_collection.each do |snapshot|
        ActiveRecord::Base.transaction do
          parent = Snapshot.find_by(:uid_ems => snapshot.parent_uid)
          child  = Snapshot.find(snapshot.id)
          child.update_attribute(:parent_id, parent.try(:id))
        end
      end
    end.freeze,
  }.freeze

  define_attribute_getters
end
