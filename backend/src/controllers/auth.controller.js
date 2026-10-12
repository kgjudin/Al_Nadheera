const { createClient } = require('@supabase/supabase-js');
const supabase = require('../config/supabase');

const anonClient = createClient(
  process.env.SUPABASE_URL,
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImlhaHd5ZmJrZG1wcGdtYmh0ZXl0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTAxODA3NTYsImV4cCI6MjEwNTc1Njc1Nn0.RIFjLbeSi8GfeXW2YKmsjwcjnq1EjUupk6zbzfmrRkA'
);

// Register a new user - pending Super Admin admission
exports.register = async (req, res) => {
  try {
    const { name, email, phone, password } = req.body;
    if (!name || !email || !password) {
      return res.status(422).json({ success: false, message: 'Name, email, and password are required' });
    }

    const trimmedEmail = email.trim().toLowerCase();

    // Check if user already exists in employees table
    const { data: existingEmp } = await supabase
      .from('employees')
      .select('id, email, status')
      .ilike('email', trimmedEmail)
      .maybeSingle();

    if (existingEmp) {
      if (existingEmp.status?.toLowerCase() === 'pending') {
        return res.status(409).json({
          success: false,
          message: 'An account with this email is already awaiting Super Admin approval.',
        });
      }
      return res.status(409).json({
        success: false,
        message: 'An account with this email already exists.',
      });
    }

    // Create auth user in Supabase
    const { data: authData, error: authErr } = await supabase.auth.admin.createUser({
      email: trimmedEmail,
      password: password,
      email_confirm: true,
      user_metadata: {
        name: name.trim(),
        phone: phone ? phone.trim() : null,
        role: 'Staff',
        status: 'Pending',
      },
    });

    if (authErr) {
      return res.status(400).json({ success: false, message: authErr.message });
    }

    const userId = authData.user.id;

    // Upsert employee record with status 'Pending'
    const { data: newEmp, error: empErr } = await supabase
      .from('employees')
      .upsert({
        id: userId,
        name: name.trim(),
        email: trimmedEmail,
        phone: phone ? phone.trim() : null,
        role: 'Staff',
        status: 'Pending',
      })
      .select()
      .single();

    if (empErr) {
      console.error('Error inserting pending employee:', empErr);
    }

    res.status(201).json({
      success: true,
      message: 'Registration submitted successfully. Pending Super Admin approval.',
      data: {
        id: userId,
        name: name.trim(),
        email: trimmedEmail,
        status: 'Pending',
      },
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// Login with verification of Super Admin approval status
exports.login = async (req, res) => {
  try {
    const { email, password } = req.body;
    if (!email || !password) {
      return res.status(422).json({ success: false, message: 'Email and password are required' });
    }

    const trimmedEmail = email.trim().toLowerCase();

    // 1. Verify password using database crypt
    const { data: verifyData, error: verifyErr } = await supabase.rpc('verify_user_credentials', {
      p_email: trimmedEmail,
      p_password: password,
    });

    if (verifyErr || !verifyData || verifyData.length === 0 || !verifyData[0].is_valid) {
      return res.status(401).json({ success: false, message: 'Invalid email or password' });
    }

    const userId = verifyData[0].user_id;

    // Check approval status in employees table
    const { data: emp } = await supabase
      .from('employees')
      .select('id, name, role, status')
      .or(`id.eq.${userId},email.ilike.${trimmedEmail}`)
      .maybeSingle();

    if (emp) {
      const role = (emp.role || '').toLowerCase();
      const status = (emp.status || 'Active').toLowerCase();

      // Only super admin can bypass; all other users must be Active
      if (role !== 'super admin') {
        if (status === 'pending') {
          return res.status(403).json({
            success: false,
            message: 'Your account is pending Super Admin approval. You can access it once the Super Admin admits your request.',
            status: 'Pending',
          });
        }
        if (status === 'declined' || status === 'rejected') {
          return res.status(403).json({
            success: false,
            message: 'Your account registration was declined by the administrator.',
            status: 'Declined',
          });
        }
        if (status === 'inactive') {
          return res.status(403).json({
            success: false,
            message: 'Your account is inactive. Please contact the administrator.',
            status: 'Inactive',
          });
        }
      }
    }

    // 2. Generate Supabase session token
    const { data: linkData, error: linkErr } = await supabase.auth.admin.generateLink({
      type: 'magiclink',
      email: trimmedEmail,
    });

    if (linkErr || !linkData || !linkData.properties?.email_otp) {
      throw new Error(linkErr ? linkErr.message : 'Failed to generate auth token');
    }

    const otp = linkData.properties.email_otp;

    // 3. Exchange OTP for an authenticated Supabase session
    const { data: sessionData, error: sessionErr } = await anonClient.auth.verifyOtp({
      email: trimmedEmail,
      token: otp,
      type: 'magiclink',
    });

    if (sessionErr || !sessionData?.session) {
      throw new Error(sessionErr ? sessionErr.message : 'Failed to authenticate session');
    }

    res.status(200).json({
      success: true,
      data: {
        session: sessionData.session,
        user: sessionData.user,
      },
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};
