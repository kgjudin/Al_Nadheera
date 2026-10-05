const supabase = require('../config/supabase');

const ALL_MODULES = [
  'dashboard',
  'sites',
  'employees',
  'budget',
  'chat',
  'products',
  'personal',
  'role_management',
  'site_summary',
  'site_tasks',
  'site_labour',
  'site_materials',
  'site_subcontractors',
  'site_additional_expenses',
  'site_budget',
  'site_chat',
  'site_edit'
];

exports.getAllRoles = async (req, res) => {
  try {
    const { data: roles, error: rolesError } = await supabase
      .from('roles')
      .select('*, permissions:role_permissions(*)')
      .order('is_system', { ascending: false })
      .order('name', { ascending: true });

    if (rolesError) throw rolesError;
    res.status(200).json({ success: true, data: roles });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

exports.getRoleById = async (req, res) => {
  try {
    const { id } = req.params;
    const { data, error } = await supabase
      .from('roles')
      .select('*, permissions:role_permissions(*)')
      .eq('id', id)
      .single();

    if (error) throw error;
    if (!data) return res.status(404).json({ success: false, message: 'Role not found' });
    res.status(200).json({ success: true, data });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

exports.createRole = async (req, res) => {
  try {
    const { name, description, permissions } = req.body;
    if (!name || !name.trim()) {
      return res.status(422).json({ success: false, message: 'Role name is required' });
    }

    const trimmedName = name.trim();

    // Check duplicate
    const { data: existing } = await supabase
      .from('roles')
      .select('id')
      .ilike('name', trimmedName)
      .maybeSingle();

    if (existing) {
      return res.status(409).json({ success: false, message: 'A role with this name already exists' });
    }

    // Insert custom role
    const { data: newRole, error: roleError } = await supabase
      .from('roles')
      .insert([{
        name: trimmedName,
        description: description || '',
        is_system: false
      }])
      .select()
      .single();

    if (roleError) throw roleError;

    // Insert permissions
    const permissionsToInsert = ALL_MODULES.map((moduleKey) => {
      const p = permissions && permissions[moduleKey] ? permissions[moduleKey] : {};
      return {
        role_id: newRole.id,
        module_key: moduleKey,
        can_view: p.can_view ?? false,
        can_create: p.can_create ?? false,
        can_edit: p.can_edit ?? false,
        can_delete: p.can_delete ?? false,
      };
    });

    const { data: insertedPerms, error: permsError } = await supabase
      .from('role_permissions')
      .insert(permissionsToInsert)
      .select();

    if (permsError) throw permsError;

    newRole.permissions = insertedPerms;
    res.status(201).json({ success: true, data: newRole });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

exports.updateRole = async (req, res) => {
  try {
    const { id } = req.params;
    const { name, description, permissions } = req.body;

    const { data: existingRole, error: fetchErr } = await supabase
      .from('roles')
      .select('*')
      .eq('id', id)
      .single();

    if (fetchErr || !existingRole) {
      return res.status(404).json({ success: false, message: 'Role not found' });
    }

    const updates = {};
    if (description !== undefined) updates.description = description;
    // Don't rename Super Admin or Admin system roles name if critical
    if (name && (!existingRole.is_system || existingRole.name !== 'Super Admin')) {
      updates.name = name.trim();
    }
    updates.updated_at = new Date().toISOString();

    if (Object.keys(updates).length > 0) {
      const { error: updateErr } = await supabase
        .from('roles')
        .update(updates)
        .eq('id', id);
      if (updateErr) throw updateErr;
    }

    // Update permissions if provided
    if (permissions && typeof permissions === 'object') {
      for (const moduleKey of Object.keys(permissions)) {
        const p = permissions[moduleKey];
        await supabase
          .from('role_permissions')
          .upsert({
            role_id: id,
            module_key: moduleKey,
            can_view: p.can_view ?? false,
            can_create: p.can_create ?? false,
            can_edit: p.can_edit ?? false,
            can_delete: p.can_delete ?? false,
            updated_at: new Date().toISOString(),
          }, { onConflict: 'role_id,module_key' });
      }
    }

    const { data: updatedRole, error: refetchErr } = await supabase
      .from('roles')
      .select('*, permissions:role_permissions(*)')
      .eq('id', id)
      .single();

    if (refetchErr) throw refetchErr;

    res.status(200).json({ success: true, data: updatedRole });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

exports.deleteRole = async (req, res) => {
  try {
    const { id } = req.params;

    const { data: role, error: fetchErr } = await supabase
      .from('roles')
      .select('*')
      .eq('id', id)
      .single();

    if (fetchErr || !role) {
      return res.status(404).json({ success: false, message: 'Role not found' });
    }

    if (role.is_system) {
      return res.status(403).json({ success: false, message: 'System roles (Super Admin, Admin, Manager, Employee) cannot be deleted' });
    }

    // Reset employees who had this role to default Employee
    const { data: defaultEmpRole } = await supabase
      .from('roles')
      .select('id')
      .eq('name', 'Employee')
      .maybeSingle();

    await supabase
      .from('employees')
      .update({ role_id: defaultEmpRole ? defaultEmpRole.id : null, role: 'Employee' })
      .eq('role_id', id);

    const { error: delErr } = await supabase
      .from('roles')
      .delete()
      .eq('id', id);

    if (delErr) throw delErr;

    res.status(200).json({ success: true, message: 'Role deleted successfully' });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

exports.getUserEffectivePermissions = async (req, res) => {
  try {
    const { userId } = req.params;

    // Find employee by id or email or auth user id
    const { data: employee, error: empErr } = await supabase
      .from('employees')
      .select('*, role_info:roles(*)')
      .eq('id', userId)
      .maybeSingle();

    if (!employee) {
      // Return default permissions (Employee level)
      return res.status(200).json({
        success: true,
        data: {
          role: 'Employee',
          is_super_admin: false,
          is_admin: false,
          permissions: buildDefaultPermissions(false)
        }
      });
    }

    const roleName = employee.role || (employee.role_info ? employee.role_info.name : 'Employee');
    const isSuperAdmin = roleName.toLowerCase() === 'super admin';

    if (isSuperAdmin) {
      const fullPerms = {};
      ALL_MODULES.forEach(m => {
        fullPerms[m] = { can_view: true, can_create: true, can_edit: true, can_delete: true };
      });
      return res.status(200).json({
        success: true,
        data: {
          role: 'Super Admin',
          role_id: employee.role_id,
          is_super_admin: true,
          is_admin: true,
          is_manager: true,
          permissions: fullPerms,
        }
      });
    }

    // Fetch role permissions
    let rolePermsList = [];
    if (employee.role_id) {
      const { data: perms } = await supabase
        .from('role_permissions')
        .select('*')
        .eq('role_id', employee.role_id);
      rolePermsList = perms || [];
    } else {
      // Find role by name
      const { data: roleByName } = await supabase
        .from('roles')
        .select('id, permissions:role_permissions(*)')
        .ilike('name', roleName)
        .maybeSingle();
      if (roleByName && roleByName.permissions) {
        rolePermsList = roleByName.permissions;
      }
    }

    // Build permission map
    const effective = {};
    ALL_MODULES.forEach(m => {
      const found = rolePermsList.find(p => p.module_key === m);
      effective[m] = found ? {
        can_view: Boolean(found.can_view),
        can_create: Boolean(found.can_create),
        can_edit: Boolean(found.can_edit),
        can_delete: Boolean(found.can_delete)
      } : {
        can_view: false,
        can_create: false,
        can_edit: false,
        can_delete: false
      };
    });

    // Apply custom overrides if employee has custom_permissions
    if (employee.custom_permissions && typeof employee.custom_permissions === 'object') {
      for (const [mod, override] of Object.entries(employee.custom_permissions)) {
        if (effective[mod] && override) {
          if (override.can_view !== undefined) effective[mod].can_view = Boolean(override.can_view);
          if (override.can_create !== undefined) effective[mod].can_create = Boolean(override.can_create);
          if (override.can_edit !== undefined) effective[mod].can_edit = Boolean(override.can_edit);
          if (override.can_delete !== undefined) effective[mod].can_delete = Boolean(override.can_delete);
        }
      }
    }

    const isAdmin = roleName.toLowerCase() === 'admin';
    const isManager = roleName.toLowerCase() === 'manager';

    res.status(200).json({
      success: true,
      data: {
        role: roleName,
        role_id: employee.role_id,
        is_super_admin: false,
        is_admin: isAdmin,
        is_manager: isManager,
        custom_permissions: employee.custom_permissions,
        permissions: effective
      }
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

exports.updateEmployeeCustomPermissions = async (req, res) => {
  try {
    const { id } = req.params;
    const { custom_permissions, role, role_id } = req.body;

    const payload = {};
    if (custom_permissions !== undefined) payload.custom_permissions = custom_permissions;
    if (role !== undefined) payload.role = role;
    if (role_id !== undefined) payload.role_id = role_id;

    const { data, error } = await supabase
      .from('employees')
      .update(payload)
      .eq('id', id)
      .select()
      .single();

    if (error) throw error;
    res.status(200).json({ success: true, data });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

function buildDefaultPermissions(isFull) {
  const perms = {};
  ALL_MODULES.forEach(m => {
    perms[m] = {
      can_view: isFull,
      can_create: isFull,
      can_edit: isFull,
      can_delete: isFull
    };
  });
  return perms;
}
