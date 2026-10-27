const supabase = require('../config/supabase');

const getReminders = async (req, res, next) => {
  try {
    const { status, category, employee_id } = req.query;

    let query = supabase
      .from('reminders')
      .select('*')
      .order('due_date', { ascending: true });

    if (status && status !== 'All') {
      if (status === 'Active') {
        query = query.neq('status', 'Completed');
      } else {
        query = query.eq('status', status);
      }
    }

    if (category && category !== 'All') {
      query = query.eq('category', category);
    }

    if (employee_id) {
      query = query.eq('employee_id', employee_id);
    }

    const { data, error } = await query;
    if (error) throw error;

    res.status(200).json({ success: true, data });
  } catch (error) {
    next(error);
  }
};

const getReminderById = async (req, res, next) => {
  try {
    const { id } = req.params;
    const { data, error } = await supabase
      .from('reminders')
      .select('*')
      .eq('id', id)
      .single();

    if (error) throw error;
    res.status(200).json({ success: true, data });
  } catch (error) {
    next(error);
  }
};

const createReminder = async (req, res, next) => {
  try {
    const payload = req.body;
    const { data, error } = await supabase
      .from('reminders')
      .insert(payload)
      .select()
      .single();

    if (error) throw error;
    res.status(201).json({ success: true, data });
  } catch (error) {
    next(error);
  }
};

const updateReminder = async (req, res, next) => {
  try {
    const { id } = req.params;
    const payload = req.body;
    const { data, error } = await supabase
      .from('reminders')
      .update(payload)
      .eq('id', id)
      .select()
      .single();

    if (error) throw error;
    res.status(200).json({ success: true, data });
  } catch (error) {
    next(error);
  }
};

const deleteReminder = async (req, res, next) => {
  try {
    const { id } = req.params;
    const { error } = await supabase
      .from('reminders')
      .delete()
      .eq('id', id);

    if (error) throw error;
    res.status(200).json({ success: true, message: 'Reminder deleted successfully' });
  } catch (error) {
    next(error);
  }
};

module.exports = {
  getReminders,
  getReminderById,
  createReminder,
  updateReminder,
  deleteReminder,
};
