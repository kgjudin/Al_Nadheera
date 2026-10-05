const supabase = require('../config/supabase');

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
    let finalRoleId = role_id;
    if (finalRoleId && !role) {
      const { data: rData } = await supabase.from('roles').select('name').eq('id', finalRoleId).maybeSingle();
      if (rData) finalRole = rData.name;
    } else if (finalRole && !finalRoleId) {
      const { data: rData } = await supabase.from('roles').select('id').ilike('name', finalRole).maybeSingle();
      if (rData) finalRoleId = rData.id;
    }

    let authUserId = null;
    
    // If an email is provided, create a Supabase Auth User so they can log in
    if (email) {
      const { data: authData, error: authError } = await supabase.auth.admin.createUser({
        email: email,
        password: 'Password123!', // Default password for new employees
        email_confirm: true,      // Auto-confirm so they can log in immediately
        user_metadata: {
          name: name,
          phone: phone,
          role: finalRole,
        }
      });
      
      if (authError) {
        console.error("Auth creation error:", authError.message);
      } else if (authData && authData.user) {
        authUserId = authData.user.id;
      }
    }
    
    const payload = { 
      employee_id, 
      name, 
      phone, 
      email, 
      role: finalRole, 
      role_id: finalRoleId,
      custom_permissions: custom_permissions || null,
      joining_date, 
      assigned_site_id, 
      status, 
      profile_image_url 
    };
    if (authUserId) {
      payload.id = authUserId; // Link the employee record to the auth user
    }

    const { data, error } = await supabase
      .from('employees')
      .insert([payload])
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
    
    if (updates.role_id && !updates.role) {
      const { data: rData } = await supabase.from('roles').select('name').eq('id', updates.role_id).maybeSingle();
      if (rData) updates.role = rData.name;
    } else if (updates.role && !updates.role_id) {
      const { data: rData } = await supabase.from('roles').select('id').ilike('name', updates.role).maybeSingle();
      if (rData) updates.role_id = rData.id;
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

