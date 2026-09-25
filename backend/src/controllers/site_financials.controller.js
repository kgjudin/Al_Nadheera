const supabase = require('../config/supabase');

// Generic handler for fetching by site_id
const getBySiteId = (table) => async (req, res) => {
  try {
    const { siteId } = req.params;
    const { data, error } = await supabase.from(table).select('*').eq('site_id', siteId).order('date', { ascending: false, nullsFirst: false });
    if (error) throw error;
    res.status(200).json({ success: true, data });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// Generic handler for creating a record
const createRecord = (table) => async (req, res) => {
  try {
    const { siteId } = req.params;
    const payload = { ...req.body, site_id: siteId };
    
    // For site_summary, calculate balance
    if (table === 'site_summary') {
      payload.balance = (payload.received_amount || 0) - (payload.cash_expenses || 0);
    }
    
    const { data, error } = await supabase.from(table).insert([payload]).select().single();
    if (error) throw error;
    res.status(201).json({ success: true, data });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// Generic handler for updating a record
const updateRecord = (table) => async (req, res) => {
  try {
    const { id } = req.params;
    const payload = { ...req.body };
    
    if (table === 'site_summary') {
      if (payload.received_amount !== undefined || payload.cash_expenses !== undefined) {
        // We'd need to fetch existing if only one is provided, but assuming client sends full payload
        payload.balance = (payload.received_amount || 0) - (payload.cash_expenses || 0);
      }
    }
    
    const { data, error } = await supabase.from(table).update(payload).eq('id', id).select().single();
    if (error) throw error;
    res.status(200).json({ success: true, data });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// Generic handler for deleting a record
const deleteRecord = (table) => async (req, res) => {
  try {
    const { id } = req.params;
    const { error } = await supabase.from(table).delete().eq('id', id);
    if (error) throw error;
    res.status(200).json({ success: true, message: 'Record deleted successfully' });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

module.exports = {
  getSummary: getBySiteId('site_summary'),
  createSummary: createRecord('site_summary'),
  updateSummary: updateRecord('site_summary'),
  deleteSummary: deleteRecord('site_summary'),

  getLabour: getBySiteId('labour_costs'),
  createLabour: createRecord('labour_costs'),
  updateLabour: updateRecord('labour_costs'),
  deleteLabour: deleteRecord('labour_costs'),

  getMaterials: getBySiteId('material_costs'),
  createMaterial: createRecord('material_costs'),
  updateMaterial: updateRecord('material_costs'),
  deleteMaterial: deleteRecord('material_costs'),

  getSubcontractors: getBySiteId('subcontractors'),
  createSubcontractor: createRecord('subcontractors'),
  updateSubcontractor: updateRecord('subcontractors'),
  deleteSubcontractor: deleteRecord('subcontractors'),

  getAdditionalExpenses: getBySiteId('additional_expenses'),
  createAdditionalExpense: createRecord('additional_expenses'),
  updateAdditionalExpense: updateRecord('additional_expenses'),
  deleteAdditionalExpense: deleteRecord('additional_expenses'),

  getBudget: getBySiteId('site_budget'),
  createBudget: createRecord('site_budget'),
  updateBudget: updateRecord('site_budget'),
  deleteBudget: deleteRecord('site_budget'),
};
