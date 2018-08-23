Trestle.resource(:vehicle_configs) do
  
  menu do
    item :vehicle_configs, icon: "fa fa-car", group: :vehicle_configs, label: "Openpilot Support"
  end

  #####
  # SCOPES
  #####
  scope :all, -> { VehicleConfig.includes(:vehicle_make, :vehicle_model, :vehicle_config_type).where(parent_id: nil).order("vehicle_makes.name, vehicle_models.name, year, vehicle_config_types.difficulty_level") }, default: true
  
  VehicleMake.with_configs.each do |make|
    scope :"#{make.name.underscore}", -> { VehicleConfig.includes(:vehicle_make, :vehicle_model, :vehicle_config_type).where(parent_id: nil).where("vehicle_makes.name = '#{make.name}'").order("vehicle_models.name, year, vehicle_config_types.difficulty_level") }
    VehicleModel.where(:vehicle_make => make).with_configs.each do |model|
      scope :"#{make.name.underscore}_#{model.name.underscore}", -> { VehicleConfig.includes(:vehicle_make, :vehicle_model, :vehicle_config_type).where(parent_id: nil).where("vehicle_makes.name = '#{make.name}' AND vehicle_models.name = '#{model.name}'").order("vehicle_models.name, year, vehicle_config_types.difficulty_level") }
    end
  end
  
  #####
  # SEARCH
  #####
  search do |query|
    if query
      VehicleConfig.where("title ILIKE ?", "%#{query}%")
    else
      VehicleConfig.all
    end
  end

  controller do
    def refresh_trims
      vehicle_config_root = admin.find_instance(params).root
      vehicle_config_root.scrape_info
      flash[:message] = "Vehicle trims list has been reloaded."
      redirect_to admin.path(:show, id: vehicle_config_root.id)
    end
    def fork
      vehicle_config_root = admin.find_instance(params).root
      new_config = vehicle_config_root.fork_config
      veh_conf_type = VehicleConfigType.find(params[:config_type])
      new_config.parent = vehicle_config_root
      new_config.vehicle_config_type = veh_conf_type
      new_config.save
      flash[:message] = "Vehicle has been forked."
      redirect_to admin.path(:show, id: new_config.id)
    end

    def clone
      vehicle_config = admin.find_instance(params)
      new_config = vehicle_config.copy_config
      new_config.save!
      flash[:message] = "Vehicle has been cloned."
      redirect_to admin.path(:show, id: new_config.id)
    end
  end

  routes do
    get :refresh_trims, :on => :member
    get :fork, :on => :member
    get :clone, :on => :member
  end

  table do |a|
    row do |vehicle|
      { class: "#{vehicle.vehicle_config_type.blank? ? "unknown" : vehicle.vehicle_config_type.slug} vehicle-config" }
    end
    column :year_range_str, header: "Year(s)"
    column :vehicle_make, header: "Make", link: false
    column :vehicle_model, header: "Model", link: false
    # column :vehicle_trim_names, header: "Trim(s)"
    # column :vehicle_make_package, header: "Required Option"
    column :compatible_trims_count, header: "Possible Trims"
    column :is_upstreamed?, header: "Upstreamed"
    column :full_support_difficulty, header: "Full Support Difficulty"
    actions
  end
  
  #####
  # F O R M
  #####
  form do |vehicle_config|
    tab :general do
      if vehicle_config.parent.blank?
        row do
          col(sm: 3, class: "year-range") do
            row do
              col(sm: 6, class: "year-start") { select :year, 2010..(Time.zone.now.year + 2) }
              col(sm: 6, class: "year-end") { select :year_end, 2010..(Time.zone.now.year + 2), label: nil }
            end
          end
          col(sm: 4) { collection_select :vehicle_make_id, VehicleMake.order(:name), :id, :name, include_blank: true }
          col(sm: 5) { collection_select :vehicle_model_id, vehicle_config.vehicle_make.blank? ? [] : vehicle_config.vehicle_make.vehicle_models.order(:name), :id, :name, include_blank: true }
          # col(sm: 5) do
          #   select :vehicle_trim_ids, (vehicle_config.vehicle_model.blank? ? [] : VehicleTrim.where(:vehicle_model => vehicle_config.vehicle_model.id).order(:name)), { label: "Trim(s)" }, { multiple: true, data: { tags: true } }
          #   # tag_select :vehicle_config_trims
          # end
        end
      else
        static_field :name, "#{vehicle_config.name.blank? ? nil : vehicle_config.name}"
    
        hidden_field :year
        hidden_field :year_end
        hidden_field :vehicle_make_id
        hidden_field :vehicle_model_id
        hidden_field :vehicle_trim_id
      end

      collection_select :vehicle_make_package_id, VehicleMakePackage.where(vehicle_make: vehicle_config.vehicle_make).order(:name), :id, :name, include_blank: true, label: "Required Factory Installed Option"
    end
    
    unless vehicle_config.new_record? || vehicle_config.vehicle_config_type.blank?
      tab :found_trims, badge: vehicle_config.compatible_trims_count do
        render "tab_toolbar", {
          :groups => [
            {
              :class => "actions",
              :items => [
                link_to("Refresh Trims", admin.path(:refresh_trims, id: instance.root.id), method: :get, class: "btn btn-default btn-block")
              ]
            }
          ]
        }
        
        table vehicle_config.compatible_trims.blank? ? [] : vehicle_config.compatible_trims, admin: :vehicle_trims do
          column :id
          column :year
          column :name, header: "Name"
          column :driver_assisted_style_names, header: "ACC/LKAS Trim(s) Option or Standard"
          
          column :has_driver_assist?, header: "Available Driver Assist", align: :center
          # column :speed
          # column :timeout_friendly, :header => "Timeout"
          # column :confirmed
        end
      end
      tab :capabilities, badge: vehicle_config.vehicle_config_capabilities.blank? ? nil : vehicle_config.vehicle_config_capabilities.size do
        render "tab_toolbar", {
          :groups => [
            {
              :class => "actions",
              :items => [
                admin_link_to("Add Capability", admin: :vehicle_config_capabilities, action: :new, class: "btn btn-default btn-list-add", params: { vehicle_config_id: vehicle_config.blank? ? nil : vehicle_config.id })
              ]
            }
          ]
        }
        
        table vehicle_config.vehicle_config_capabilities.blank? ? [] : vehicle_config.vehicle_config_capabilities.includes(:vehicle_capability).order('vehicle_capabilities.name'), admin: :vehicle_config_capabilities do
          column :name
          column :speed
          column :timeout_friendly, :header => "Timeout"
          column :confirmed
        end
      end
      tab :capabilities, badge: vehicle_config.vehicle_config_capabilities.blank? ? nil : vehicle_config.vehicle_config_capabilities.size do
        render "tab_toolbar", {
          :groups => [
            {
              :class => "actions",
              :items => [
                admin_link_to("Add Capability", admin: :vehicle_config_capabilities, action: :new, class: "btn btn-default btn-list-add", params: { vehicle_config_id: vehicle_config.blank? ? nil : vehicle_config.id })
              ]
            }
          ]
        }
        
        table vehicle_config.vehicle_config_capabilities.blank? ? [] : vehicle_config.vehicle_config_capabilities.includes(:vehicle_capability).order('vehicle_capabilities.name'), admin: :vehicle_config_capabilities do
          column :name
          column :speed
          column :timeout_friendly, :header => "Timeout"
          column :confirmed
        end
      end
      tab :modifications, badge: vehicle_config.vehicle_config_modifications.blank? ? nil : vehicle_config.vehicle_config_modifications.size do
        render "tab_toolbar", {
          :groups => [
            {
              :class => "actions",
              :items => [
                admin_link_to("Add Modification", admin: :vehicle_config_modifications, action: :new, class: "btn btn-default btn-list-add", params: { vehicle_config_id: vehicle_config.blank? ? nil : vehicle_config.id })
              ]
            }
          ]
        }
        table vehicle_config.vehicle_config_modifications.includes(:modification).order('modifications.name'), admin: :vehicle_config_modifications do
          column :modification, dialog: true
          column :hardware_item_names
        end
        tab :children, badge: vehicle_config.forks.blank? ? nil : vehicle_config.forks.size do
          # render "tab_toolbar", {
          #   :groups => [
          #     {
          #       :class => "actions",
          #       :items => [
          #         admin_link_to("Add Capability", admin: :vehicle_config_capabilities, action: :new, class: "btn btn-default btn-list-add", params: { vehicle_config_id: vehicle_config.blank? ? nil : vehicle_config.id })
          #       ]
          #     }
          #   ]
          # }
          
          table vehicle_config.forks.blank? ? [] : vehicle_config.forks.order(:id), admin: :vehicle_configs do
            column :name
            actions
          end
        end
      end if vehicle_config.parent

      #####
      # CODE TAB
      #####
      tab :code do
        render "tab_toolbar", {
          :groups => [
            {
              :class => "actions",
              :items => [
                admin_link_to("Link Codebase", admin: :vehicle_config_repositories, action: :new, class: "btn btn-default btn-list-add", params: { vehicle_config_id: vehicle_config.blank? ? nil : vehicle_config.id })
              ]
            }
          ]
        }
        collection_select :vehicle_config_status_id, VehicleConfigStatus.order(:name), :id, :name, include_blank: true, label: "Status of the codebase"

        table vehicle_config.vehicle_config_repositories, admin: :vehicle_config_repositories do
          column :name
        end
      end if vehicle_config.parent
      
      tab :changes do
        table vehicle_config.versions, admin: :vehicle_config_versions do
          column :name
        end
      end
      sidebar do
        render "fork_links", :instance => vehicle_config
        concat(
          link_to(
            "<span class=\"fa fa-copy\"></span> Duplicate Entire Config".html_safe, 
            admin.path(:clone, id: vehicle_config.blank? ? nil : vehicle_config.root.id), 
            method: :get, 
            class: "btn btn-default btn-block", 
            confirm: 'This will copy the Factory config and all of its sub-configs to an entirely new vehicle config.\nAre you sure this is what you want to do?'
          )
        )
        # collection_select :parent_id, VehicleConfig.where.not(id: vehicle_config.id).includes(:vehicle_make,:vehicle_model).where(:vehicle_make => vehicle_config.vehicle_make.blank? ? nil : vehicle_config.vehicle_make,:vehicle_model => vehicle_config.vehicle_model.blank? ? nil : vehicle_config.vehicle_model).where("parent_id IS NULL").order("vehicle_models.name, year"), :id, :name, include_blank: true, label: "Associate to new parent"
      end
    end
    
  end
  
end
