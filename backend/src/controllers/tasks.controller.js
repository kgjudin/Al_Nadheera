const supabase = require('../config/supabase');

exports.getTasksBySite = async (req, res) => {
  try {
    const { siteId } = req.params;
    const { data, error } = await supabase
      .from('tasks')
      .select('*, employee:employees(name)')
      .eq('site_id', siteId)
      .order('created_at', { ascending: false });
      
    if (error) throw error;
    res.status(200).json({ success: true, data });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

exports.createTask = async (req, res) => {
  try {
    const { siteId } = req.params;
    const { title, description, assigned_employee_id, start_date, due_date, status } = req.body;
    
    if (!title) return res.status(422).json({ success: false, message: 'Title is required' });

    const { data, error } = await supabase
      .from('tasks')
      .insert([{ 
        site_id: siteId, 
        title, 
        description, 
        assigned_employee_id, 
        start_date, 
        due_date, 
        status: status || 'Pending'
      }])
      .select()
      .single();
      
    if (error) throw error;
    res.status(201).json({ success: true, data });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

exports.updateTask = async (req, res) => {
  try {
    const { id } = req.params;
    const updates = req.body;
    
    const { data, error } = await supabase
      .from('tasks')
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

exports.deleteTask = async (req, res) => {
  try {
    const { id } = req.params;
    const { error } = await supabase.from('tasks').delete().eq('id', id);
    if (error) throw error;
    res.status(200).json({ success: true, message: 'Task deleted successfully' });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};
