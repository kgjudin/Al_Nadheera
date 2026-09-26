const supabase = require('../config/supabase');

exports.getDashboardMetrics = async (req, res) => {
  try {
    const { data: sites, error } = await supabase.from('sites').select('*');
    if (error) throw error;
    
    const totalSites = sites.length;
    const activeSites = sites.filter(s => s.status === 'Active').length;
    
    // Sum site assigned budget + income section totals
    const siteAssignedSum = sites.reduce((sum, site) => sum + Number(site.assigned_budget || 0), 0);
    
    const { data: incomeSecs } = await supabase.from('income_sections').select('amount');
    const incomeSecsSum = (incomeSecs || []).reduce((sum, sec) => sum + Number(sec.amount || 0), 0);
    const totalAssignedBudget = siteAssignedSum + incomeSecsSum;
    
    // 1. Fetch Budget Files Spent (income_expenses)
    const { data: incomeExps } = await supabase.from('income_expenses').select('amount');
    const incomeExpsSpent = (incomeExps || []).reduce((sum, exp) => sum + Number(exp.amount || 0), 0);

    // 2. Fetch Site Budget Spent (site_budget)
    const { data: siteBudgets } = await supabase.from('site_budget').select('site_id, income_spend');
    const siteBudgetsSpent = (siteBudgets || []).reduce((sum, b) => sum + Number(b.income_spend || 0), 0);

    // 3. Fetch Site Summary Expenses
    const { data: summaries } = await supabase.from('site_summary').select('site_id, cash_expenses');
    const summariesSpent = (summaries || []).reduce((sum, s) => sum + Number(s.cash_expenses || 0), 0);

    // 4. Fetch Labour Costs
    const { data: labours } = await supabase.from('labour_costs').select('site_id, amount');
    const laboursSpent = (labours || []).reduce((sum, l) => sum + Number(l.amount || 0), 0);

    // 5. Fetch Material Costs
    const { data: materials } = await supabase.from('material_costs').select('site_id, invoice_amount');
    const materialsSpent = (materials || []).reduce((sum, m) => sum + Number(m.invoice_amount || 0), 0);

    // 6. Fetch Subcontractors
    const { data: subcontracts } = await supabase.from('subcontractors').select('site_id, invoice_amount');
    const subcontractsSpent = (subcontracts || []).reduce((sum, sc) => sum + Number(sc.invoice_amount || 0), 0);

    // 7. Fetch Additional Expenses
    const { data: additionals } = await supabase.from('additional_expenses').select('site_id, amount');
    const additionalsSpent = (additionals || []).reduce((sum, a) => sum + Number(a.amount || 0), 0);

    const totalSpent = incomeExpsSpent + siteBudgetsSpent + summariesSpent + laboursSpent + materialsSpent + subcontractsSpent + additionalsSpent;
    const remainingBudget = totalAssignedBudget - totalSpent;

    // Build per-site spent mapping
    const siteSpentMap = {};
    const addSiteSpent = (siteId, amt) => {
      if (!siteId) return;
      siteSpentMap[siteId] = (siteSpentMap[siteId] || 0) + Number(amt || 0);
    };

    (summaries || []).forEach(s => addSiteSpent(s.site_id, s.cash_expenses));

    const enrichedSites = sites.map(site => ({
      ...site,
      spent: siteSpentMap[site.id] || 0,
    }));

    const { count: totalEmployees } = await supabase
      .from('employees')
      .select('*', { count: 'exact', head: true });

    res.status(200).json({
      success: true,
      data: {
        totalSites,
        activeSites,
        totalEmployees: totalEmployees || 0,
        totalAssignedBudget,
        totalSpent,
        remainingBudget,
        recentSites: enrichedSites.slice(0, 5)
      }
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

