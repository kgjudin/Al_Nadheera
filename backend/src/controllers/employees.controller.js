const supabase = require('../config/supabase');
const { fetchNextEmployeeId } = require('../utils/employeeIdService');

exports.getAllEmployees = async (req, res) => {
  try {
    // We join with sites to get the assigned site name
    const { data, error } = await supabase
      .from('employees')
      .select('*, site:sites(name)')
      .order('created_at', { ascending: false });
      
    if (error) throw error;
    res.status(200).json({ success: true, data });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

exports.getEmployeeById = async (req, res) => {
  try {
    const { id } = req.params;
    const { data, error } = await supabase
      .from('employees')
      .select('*, site:sites(name)')
      .eq('id', id)
      .single();
      
    if (error) throw error;
    if (!data) return res.status(404).json({ success: false, message: 'Employee not found' });
    res.status(200).json({ success: true, data });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

exports.createEmployee = async (req, res) => {
  try {
    const { employee_id, name, phone, email, role, role_id, custom_permissions, joining_date, assigned_site_id, status, profile_image_url } = req.body;
    if (!name) {
      return res.status(422).json({ success: false, message: 'Name is required' });
    }
    
    // Resolve role and role_id if one is provided
    let finalRole = role || 'Employee';
    if (finalRole.trim().toLowerCase() === 'staff') finalRole = 'Employee';
    let finalRoleId = role_id;
    if (finalRoleId && !role) {
      const { data: rData } = await supabase.from('roles').select('name').eq('id', finalRoleId).maybeSingle();
      if (rData) finalRole = rData.name;
    } else if (finalRole && !finalRoleId) {
      const { data: rData } = await supabase.from('roles').select('id').ilike('name', finalRole).maybeSingle();
      if (rData) finalRoleId = rData.id;
    }
    if (!finalRoleId && finalRole.trim().toLowerCase() === 'employee') {
      finalRoleId = '7be40544-c6a7-4f2b-80e5-a7d9e663dcde';
    }

    // Auto-generate employee ID if not provided (e.g. ANCC-EMP-001)
    let finalEmpId = employee_id;
    if (!finalEmpId || finalEmpId.trim() === '') {
      finalEmpId = await fetchNextEmployeeId();
    }

    let authUserId = null;
    
    // If an email is provided, create a Supabase Auth User so they can log in
    if (email) {
      const trimmedEmail = email.trim().toLowerCase();
      const { data: authData, error: authError } = await supabase.auth.admin.createUser({
        email: trimmedEmail,
        password: 'Password123!', // Default password for new employees
        email_confirm: true,      // Auto-confirm so they can log in immediately
        user_metadata: {
          name: name,
          phone: phone,
          role: finalRole,
          employee_id: finalEmpId,
        }
      });
      
      if (authError) {
        console.error("Auth creation error:", authError.message);
        // If user already exists in auth, retrieve their id so we can link
        if (authError.message?.toLowerCase().includes('already') || authError.status === 422) {
          try {
            const { data: userList } = await supabase.auth.admin.listUsers();
            const existing = userList?.users?.find(u => u.email?.toLowerCase() === trimmedEmail);
            if (existing) {
              authUserId = existing.id;
            }
          } catch (_) {}
        }
      } else if (authData && authData.user) {
        authUserId = authData.user.id;
      }
    }

    const payload = { 
      employee_id: finalEmpId, 
      name, 
      phone: phone || null, 
      email: email ? email.trim().toLowerCase() : null, 
      role: finalRole, 
      role_id: finalRoleId,
      custom_permissions: custom_permissions || null,
      joining_date: joining_date || null, 
      assigned_site_id: assigned_site_id || null, 
      status: status || 'Active', 
      profile_image_url: profile_image_url || null,
    };
    if (authUserId) {
      payload.id = authUserId; // Link the employee record to the auth user
    }

    // Use upsert to gracefully handle triggers on auth.users that pre-insert employees
    const { data, error } = await supabase
      .from('employees')
      .upsert(payload, { onConflict: 'id' })
      .select()
      .single();
      
    if (error) throw error;
    res.status(201).json({ success: true, data, default_password: authUserId ? 'Password123!' : null });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

exports.updateEmployee = async (req, res) => {
  try {
    const { id } = req.params;
    const updates = { ...req.body };
    
    if (updates.role && updates.role.trim().toLowerCase() === 'staff') {
      updates.role = 'Employee';
    }
    if (updates.role_id && !updates.role) {
      const { data: rData } = await supabase.from('roles').select('name').eq('id', updates.role_id).maybeSingle();
      if (rData) updates.role = rData.name;
    } else if (updates.role && !updates.role_id) {
      const { data: rData } = await supabase.from('roles').select('id').ilike('name', updates.role).maybeSingle();
      if (rData) updates.role_id = rData.id;
    }
    if (!updates.role_id && updates.role && updates.role.trim().toLowerCase() === 'employee') {
      updates.role_id = '7be40544-c6a7-4f2b-80e5-a7d9e663dcde';
    }

    // Ensure employee has an employee_id in standard format
    const { data: currentEmp } = await supabase.from('employees').select('employee_id').eq('id', id).maybeSingle();
    if (!currentEmp || !currentEmp.employee_id) {
      updates.employee_id = await fetchNextEmployeeId();
    }

    const { data, error } = await supabase
      .from('employees')
      .update(updates)
      .eq('id', id)
      .select()
      .single();
      
    if (error) throw error;
    res.status(200).json({ success: true, data });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

exports.deleteEmployee = async (req, res) => {
  try {
    const { id } = req.params;
    const { error } = await supabase.from('employees').delete().eq('id', id);
    if (error) throw error;
    res.status(200).json({ success: true, message: 'Employee deleted successfully' });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

exports.changePassword = async (req, res) => {
  try {
    const { id } = req.params;
    const { password } = req.body;
    
    if (!password || password.length < 6) {
      return res.status(400).json({ success: false, message: 'Password must be at least 6 characters long' });
    }

    // Try updating password in Supabase Auth directly
    const { data, error } = await supabase.auth.admin.updateUserById(id, {
      password: password,
    });

    if (error) {
      console.warn('Update user password error, checking if user exists:', error.message);
      // If user doesn't exist in auth yet (e.g. employee without auth account), create one
      const { data: emp } = await supabase
        .from('employees')
        .select('email, name')
        .eq('id', id)
        .single();

      if (emp && emp.email) {
        const { error: createError } = await supabase.auth.admin.createUser({
          id: id,
          email: emp.email,
          password: password,
          email_confirm: true,
          user_metadata: { name: emp.name },
        });
        if (createError) {
          return res.status(400).json({ success: false, message: createError.message });
        }
        return res.status(200).json({ success: true, message: 'Password set successfully' });
      }
      return res.status(400).json({ success: false, message: error.message });
    }

    res.status(200).json({ success: true, message: 'Password updated successfully' });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

exports.approveEmployee = async (req, res) => {
  try {
    const { id } = req.params;
    const { role, role_id, assigned_site_id } = req.body;

    const updates = { status: 'Active' };
    if (role) updates.role = role;
    if (role_id) updates.role_id = role_id;
    if (assigned_site_id !== undefined) updates.assigned_site_id = assigned_site_id;

    // Resolve role name if role_id is provided without role
    if (updates.role && updates.role.trim().toLowerCase() === 'staff') {
      updates.role = 'Employee';
    }
    if (updates.role_id && !updates.role) {
      const { data: rData } = await supabase.from('roles').select('name').eq('id', updates.role_id).maybeSingle();
      if (rData) updates.role = rData.name;
    } else if (updates.role && !updates.role_id) {
      const { data: rData } = await supabase.from('roles').select('id').ilike('name', updates.role).maybeSingle();
      if (rData) updates.role_id = rData.id;
    }
    if (!updates.role_id && updates.role && updates.role.trim().toLowerCase() === 'employee') {
      updates.role_id = '7be40544-c6a7-4f2b-80e5-a7d9e663dcde';
    }

    // Ensure employee has an employee_id in standard format
    const { data: currentEmp } = await supabase.from('employees').select('employee_id').eq('id', id).maybeSingle();
    if (!currentEmp || !currentEmp.employee_id) {
      updates.employee_id = await fetchNextEmployeeId();
    }

    const { data, error } = await supabase
      .from('employees')
      .update(updates)
      .eq('id', id)
      .select()
      .single();

    if (error) throw error;

    // Also update auth user metadata if role was updated
    if (updates.role) {
      try {
        await supabase.auth.admin.updateUserById(id, {
          user_metadata: { role: updates.role, status: 'Active' },
        });
      } catch (_) {}
    }

    res.status(200).json({ success: true, message: 'User approved and admitted successfully', data });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

exports.declineEmployee = async (req, res) => {
  try {
    const { id } = req.params;
    const { data, error } = await supabase
      .from('employees')
      .update({ status: 'Declined' })
      .eq('id', id)
      .select()
      .single();

    if (error) throw error;

    try {
      await supabase.auth.admin.updateUserById(id, {
        user_metadata: { status: 'Declined' },
      });
    } catch (_) {}

    res.status(200).json({ success: true, message: 'User registration declined successfully', data });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};


