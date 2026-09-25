const supabase = require('../config/supabase');

const getSiteFinancials = async (siteId) => {
  const [
    { data: summaries },
    { data: siteBudgets },
    { data: labours },
    { data: materials },
    { data: subcontracts },
    { data: additionals }
  ] = await Promise.all([
    supabase.from('site_summary').select('received_amount, cash_expenses').eq('site_id', siteId),
    supabase.from('site_budget').select('income_came, income_spend').eq('site_id', siteId),
    supabase.from('labour_costs').select('amount').eq('site_id', siteId),
    supabase.from('material_costs').select('invoice_amount').eq('site_id', siteId),
    supabase.from('subcontractors').select('invoice_amount').eq('site_id', siteId),
    supabase.from('additional_expenses').select('amount').eq('site_id', siteId)
  ]);

  const receivedSummary = (summaries || []).reduce((sum, s) => sum + Number(s.received_amount || 0), 0) +
                          (siteBudgets || []).reduce((sum, b) => sum + Number(b.income_came || 0), 0);

  const spent = (summaries || []).reduce((sum, s) => sum + Number(s.cash_expenses || 0), 0) +
                (siteBudgets || []).reduce((sum, b) => sum + Number(b.income_spend || 0), 0) +
                (labours || []).reduce((sum, l) => sum + Number(l.amount || 0), 0) +
                (materials || []).reduce((sum, m) => sum + Number(m.invoice_amount || 0), 0) +
                (subcontracts || []).reduce((sum, sc) => sum + Number(sc.invoice_amount || 0), 0) +
                (additionals || []).reduce((sum, a) => sum + Number(a.amount || 0), 0);

  return { receivedSummary, spent };
};

exports.getAllSites = async (req, res) => {
  try {
    const { data: sites, error } = await supabase.from('sites').select('*').order('created_at', { ascending: false });
    if (error) throw error;

    const enrichedSites = await Promise.all((sites || []).map(async (site) => {
      const fin = await getSiteFinancials(site.id);
      return { ...site, spent: fin.spent, received_summary: fin.receivedSummary };
    }));

    res.status(200).json({ success: true, data: enrichedSites });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

exports.getSiteById = async (req, res) => {
  try {
    const { id } = req.params;
    const { data, error } = await supabase.from('sites').select('*').eq('id', id).single();
    if (error) throw error;
    if (!data) return res.status(404).json({ success: false, message: 'Site not found' });

    const fin = await getSiteFinancials(id);
    const enrichedSite = { ...data, spent: fin.spent, received_summary: fin.receivedSummary };

    res.status(200).json({ success: true, data: enrichedSite });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

exports.createSite = async (req, res) => {
  try {
    const { name, code, client_name, location, start_date, status, assigned_budget } = req.body;
    if (!name || assigned_budget === undefined) {
      return res.status(422).json({ success: false, message: 'Name and assigned_budget are required' });
    }
    
    const { data, error } = await supabase
      .from('sites')
      .insert([{ name, code, client_name, location, start_date, status, assigned_budget }])
      .select()
      .single();
      
    if (error) throw error;
    res.status(201).json({ success: true, data });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

exports.updateSite = async (req, res) => {
  try {
    const { id } = req.params;
    const updates = req.body;
    
    const { data, error } = await supabase
      .from('sites')
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

exports.deleteSite = async (req, res) => {
  try {
    const { id } = req.params;
    const { error } = await supabase.from('sites').delete().eq('id', id);
    if (error) throw error;
    res.status(200).json({ success: true, message: 'Site deleted successfully' });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};
