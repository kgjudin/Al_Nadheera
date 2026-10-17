const supabase = require('../config/supabase');

exports.getAllProducts = async (req, res) => {
  try {
    const { data, error } = await supabase.from('products').select('*').order('created_at', { ascending: false });
    if (error) throw error;
    res.status(200).json({ success: true, data });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

exports.getProductById = async (req, res) => {
  try {
    const { id } = req.params;
    const { data, error } = await supabase.from('products').select('*').eq('id', id).single();
    if (error) throw error;
    if (!data) return res.status(404).json({ success: false, message: 'Product not found' });
    res.status(200).json({ success: true, data });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

exports.createProduct = async (req, res) => {
  try {
    const { name, unit, price, class_name, class_id, submodule_name, submodule_id } = req.body;
    if (!name) {
      return res.status(422).json({ success: false, message: 'Product name is required' });
    }

    const payload = {
      name,
      unit: unit || null,
      price: parseFloat(price) || 0,
      class_name: class_name || null,
      class_id: class_id || null,
      submodule_name: submodule_name || null,
      submodule_id: submodule_id || null,
    };

    const { data, error } = await supabase
      .from('products')
      .insert([payload])
      .select()
      .single();

    if (error) throw error;
    res.status(201).json({ success: true, data });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

exports.updateProduct = async (req, res) => {
  try {
    const { id } = req.params;
    const updates = req.body;

    const { data, error } = await supabase
      .from('products')
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

exports.deleteProduct = async (req, res) => {
  try {
    const { id } = req.params;
    const { error } = await supabase.from('products').delete().eq('id', id);
    if (error) throw error;
    res.status(200).json({ success: true, message: 'Product deleted successfully' });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// ==================== PRODUCT CLASSES ====================
exports.getAllClasses = async (req, res) => {
  try {
    const { data, error } = await supabase.from('product_classes').select('*').order('name');
    if (error) throw error;
    res.status(200).json({ success: true, data });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

exports.createClass = async (req, res) => {
  try {
    const { name } = req.body;
    if (!name || !name.trim()) {
      return res.status(422).json({ success: false, message: 'Class name is required' });
    }
    const { data, error } = await supabase
      .from('product_classes')
      .insert([{ name: name.trim() }])
      .select()
      .single();
    if (error) throw error;
    res.status(201).json({ success: true, data });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

exports.deleteClass = async (req, res) => {
  try {
    const { id } = req.params;
    const { error } = await supabase.from('product_classes').delete().eq('id', id);
    if (error) throw error;
    res.status(200).json({ success: true, message: 'Class deleted successfully' });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// ==================== PRODUCT SUB-MODULES ====================
exports.getAllSubmodules = async (req, res) => {
  try {
    const { class_id, class_name } = req.query;
    let query = supabase.from('product_submodules').select('*').order('name');
    if (class_id) query = query.eq('class_id', class_id);
    if (class_name) query = query.eq('class_name', class_name);
    const { data, error } = await query;
    if (error) throw error;
    res.status(200).json({ success: true, data });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

exports.createSubmodule = async (req, res) => {
  try {
    const { class_id, class_name, name } = req.body;
    if (!name || !name.trim()) {
      return res.status(422).json({ success: false, message: 'Sub-module name is required' });
    }
    if (!class_name && !class_id) {
      return res.status(422).json({ success: false, message: 'Class is required' });
    }

    const payload = {
      name: name.trim(),
      class_name: class_name ? class_name.trim() : '',
      class_id: class_id || null,
    };

    const { data, error } = await supabase
      .from('product_submodules')
      .insert([payload])
      .select()
      .single();
    if (error) throw error;
    res.status(201).json({ success: true, data });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

exports.deleteSubmodule = async (req, res) => {
  try {
    const { id } = req.params;
    const { error } = await supabase.from('product_submodules').delete().eq('id', id);
    if (error) throw error;
    res.status(200).json({ success: true, message: 'Sub-module deleted successfully' });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};
