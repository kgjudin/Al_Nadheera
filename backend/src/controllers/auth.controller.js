const { createClient } = require('@supabase/supabase-js');
const supabase = require('../config/supabase');

const anonClient = createClient(
  process.env.SUPABASE_URL,
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImlhaHd5ZmJrZG1wcGdtYmh0ZXl0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTAxODA3NTYsImV4cCI6MjEwNTc1Njc1Nn0.RIFjLbeSi8GfeXW2YKmsjwcjnq1EjUupk6zbzfmrRkA'
);

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
