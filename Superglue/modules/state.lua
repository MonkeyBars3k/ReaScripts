-- @noindex

local State = {

  user = {
    time_selection_before_action = {},
    item_selection = nil,
    track_selection = nil,
    wants_to_depool_all_siblings = nil
  },

  action = {

    edit_or_unglue = {
      restored_items = nil,
      validated_items = nil,
      validated_track = nil,
      track_freemode = nil
    },

    edit = {
      changed_pool_ids = nil
    },

    glue = {
      all_glued_superitems = nil,
      changed_pool_ids = nil,
      current_track = nil,
      overglued_superitems = {}
    },

    depool = {
      new_pool_ids = nil
    }
  },

  pool = {
    active_glue_pool_id = nil,

    parent_pool_ids_on_this_track = {
      descendant_to_ancestor = nil
    }
  },

  superitem = {
    position_changed_since_last_glue = false,
    offset_changed_since_last_glue = false,
    active_instance_length_has_changed = nil,
    reglue_position_change_affect_on_length = nil,
    pool_parent_last_glue_length = nil,
    this_previously_depooled_superitem_has_not_been_edited = nil,

    delta = {
      position_during_glue = 0,
      offset_since_last_glue = 0,
      source_position_adjustment = 0
    },

    params = {
      ancestor_pools = {},

      last_glue = {
        edited_pool = nil
      },

      fresh_glue = {
        current_pool = nil,
        edited_pool = nil
      },

      post_glue = {
        edited_pool = nil
      },

      preedit = {
        edited_pool = nil,
        current_pool = nil
      },

      preunglue = {
        unglued_pool = nil
      }
    }
  },

  restored_items = {
    -- position_delta_near_project_start = 0,
    first_restored_item_last_glue_delta_to_parent = nil,
    last_glue_stored_item__states = nil,
    preglue_restored_item__states = nil,
    unselected_contained_items = nil
  },

  propagation = {
    user_responses = {},
    user_wants_option = {}
  }
}



return State
