const { supabase } = require('../config/supabase');

const getIpcDocuments = async (req, res, next) => {
  try {
    const { data, error } = await supabase
      .from('ipc_documents')
      .select('*')
      .order('created_at', { ascending: false });

    if (error) throw error;
    res.status(200).json({ success: true, data });
  } catch (error) {
    next(error);
  }
};

const getIpcDocumentById = async (req, res, next) => {
  try {
    const { id } = req.params;
    const { data, error } = await supabase
      .from('ipc_documents')
      .select('*, ipc_items(*)')
      .eq('id', id)
      .single();

    if (error) throw error;
    res.status(200).json({ success: true, data });
  } catch (error) {
    next(error);
  }
};

const createIpcDocument = async (req, res, next) => {
  try {
    const {
      document_number,
      project_name,
      client_name,
      date,
      status,
      total_amount,
      items = [],
      notes,
    } = req.body;

    const { data: doc, error: docError } = await supabase
      .from('ipc_documents')
      .insert({
        document_number,
        project_name,
        client_name,
        date: date || new Date().toISOString().split('T')[0],
        status: status || 'Draft',
        total_amount: total_amount || 0,
        items,
        notes,
      })
      .select()
      .single();

    if (docError) throw docError;

    if (items.length > 0) {
      const itemsPayload = items.map((item, idx) => ({
        ipc_id: doc.id,
        item_type: item.item_type || 'item',
        item_number: item.item_number || null,
        description: item.description || '',
        unit: item.unit || null,
        quantity: item.quantity || 0,
        rate: item.rate || 0,
        amount: item.amount || 0,
        sort_order: item.sort_order ?? idx,
        class_name: item.class_name || null,
        submodule_name: item.submodule_name || null,
        product_id: item.product_id || null,
      }));

      const { error: itemsError } = await supabase
        .from('ipc_items')
        .insert(itemsPayload);

      if (itemsError) {
        console.warn('Failed to insert into ipc_items relational table:', itemsError);
      }
    }

    res.status(201).json({ success: true, data: doc });
  } catch (error) {
    next(error);
  }
};

const updateIpcDocument = async (req, res, next) => {
  try {
    const { id } = req.params;
    const {
      document_number,
      project_name,
      client_name,
      date,
      status,
      total_amount,
      items,
      notes,
    } = req.body;

    const payload = {
      updated_at: new Date().toISOString(),
    };
    if (document_number !== undefined) payload.document_number = document_number;
    if (project_name !== undefined) payload.project_name = project_name;
    if (client_name !== undefined) payload.client_name = client_name;
    if (date !== undefined) payload.date = date;
    if (status !== undefined) payload.status = status;
    if (total_amount !== undefined) payload.total_amount = total_amount;
    if (items !== undefined) payload.items = items;
    if (notes !== undefined) payload.notes = notes;

    const { data: doc, error: docError } = await supabase
      .from('ipc_documents')
      .update(payload)
      .eq('id', id)
      .select()
      .single();

    if (docError) throw docError;

    if (items && Array.isArray(items)) {
      // Refresh ipc_items relational table
      await supabase.from('ipc_items').delete().eq('ipc_id', id);

      if (items.length > 0) {
        const itemsPayload = items.map((item, idx) => ({
          ipc_id: id,
          item_type: item.item_type || 'item',
          item_number: item.item_number || null,
          description: item.description || '',
          unit: item.unit || null,
          quantity: item.quantity || 0,
          rate: item.rate || 0,
          amount: item.amount || 0,
          sort_order: item.sort_order ?? idx,
          class_name: item.class_name || null,
          submodule_name: item.submodule_name || null,
          product_id: item.product_id || null,
        }));

        await supabase.from('ipc_items').insert(itemsPayload);
      }
    }

    res.status(200).json({ success: true, data: doc });
  } catch (error) {
    next(error);
  }
};

const deleteIpcDocument = async (req, res, next) => {
  try {
    const { id } = req.params;
    const { error } = await supabase.from('ipc_documents').delete().eq('id', id);
    if (error) throw error;
    res.status(200).json({ success: true, message: 'IPC Document deleted successfully' });
  } catch (error) {
    next(error);
  }
};

module.exports = {
  getIpcDocuments,
  getIpcDocumentById,
  createIpcDocument,
  updateIpcDocument,
  deleteIpcDocument,
};
