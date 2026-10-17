const supabase = require('../config/supabase');

// Helper to unpack material remarks if it contains JSON with attachments
const unpackMaterialData = (item) => {
  if (!item) return item;
  if (item.remarks && typeof item.remarks === 'string' && item.remarks.startsWith('{') && item.remarks.endsWith('}')) {
    try {
      const parsed = JSON.parse(item.remarks);
      if (parsed && typeof parsed === 'object') {
        if (parsed.attachments !== undefined || parsed.text !== undefined) {
          item.attachments = parsed.attachments || [];
          item.remarks = parsed.text || '';
          return item;
        }
      }
    } catch (_) {}
  }
  if (!item.attachments) item.attachments = [];
  return item;
};

// Generic handler for fetching by site_id
const getBySiteId = (table) => async (req, res) => {
  try {
    const { siteId } = req.params;
    const { data, error } = await supabase.from(table).select('*').eq('site_id', siteId).order('date', { ascending: false, nullsFirst: false });
    if (error) throw error;
    if (table === 'material_costs' && Array.isArray(data)) {
      data.forEach(unpackMaterialData);
    }
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

    // For labour_costs, 'amount' is GENERATED ALWAYS AS (quantity * rate) STORED in Postgres
    if (table === 'labour_costs') {
      delete payload.amount;
    }

    if (table === 'material_costs' && payload.attachments !== undefined) {
      const attachments = payload.attachments;
      const text = payload.remarks || '';
      payload.remarks = JSON.stringify({
        text: text,
        attachments: attachments,
      });
      delete payload.attachments;
    }
    
    const { data, error } = await supabase.from(table).insert([payload]).select().single();
    if (error) throw error;
    if (table === 'material_costs' && data) {
      unpackMaterialData(data);
    }
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

    // For labour_costs, 'amount' is GENERATED ALWAYS AS (quantity * rate) STORED in Postgres
    if (table === 'labour_costs') {
      delete payload.amount;
    }

    if (table === 'material_costs' && payload.attachments !== undefined) {
      const attachments = payload.attachments;
      const text = payload.remarks || '';
      payload.remarks = JSON.stringify({
        text: text,
        attachments: attachments,
      });
      delete payload.attachments;
    }
    
    const { data, error } = await supabase.from(table).update(payload).eq('id', id).select().single();
    if (error) throw error;
    if (table === 'material_costs' && data) {
      unpackMaterialData(data);
    }
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

  uploadFile: async (req, res) => {
    try {
      const { fileName, base64Data, contentType, folder = 'materials' } = req.body;
      if (!fileName || !base64Data) {
        return res.status(400).json({ success: false, message: 'fileName and base64Data are required' });
      }

      const ext = fileName.includes('.') ? fileName.split('.').pop() : 'dat';
      const cleanExt = ext.replace(/[^a-zA-Z0-9]/g, '');
      const uniqueName = `${Date.now()}_${Math.random().toString(36).substring(2, 9)}.${cleanExt}`;
      const storagePath = `${folder}/${uniqueName}`;

      const buffer = Buffer.from(base64Data, 'base64');
      const { error } = await supabase.storage.from('site-attachments').upload(storagePath, buffer, {
        contentType: contentType || 'application/octet-stream',
        upsert: true,
      });

      if (error) throw error;

      const { data } = supabase.storage.from('site-attachments').getPublicUrl(storagePath);
      return res.status(200).json({
        success: true,
        url: data.publicUrl,
        fileName,
      });
    } catch (error) {
      console.error('Upload error:', error);
      return res.status(500).json({ success: false, message: error.message });
    }
  },
};
