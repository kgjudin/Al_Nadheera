import 'package:flutter/material.dart';

class AppModules {
  // Top-Level Main Modules
  static const String dashboard = 'dashboard';
  static const String sites = 'sites';
  static const String employees = 'employees';
  static const String budget = 'budget';
  static const String chat = 'chat';
  static const String products = 'products';
  static const String personal = 'personal';
  static const String roleManagement = 'role_management';

  // Site Sub-Options / Tabs Inside Site Details
  static const String siteSummary = 'site_summary';
  static const String siteTasks = 'site_tasks';
  static const String siteLabour = 'site_labour';
  static const String siteMaterials = 'site_materials';
  static const String siteSubcontractors = 'site_subcontractors';
  static const String siteAdditionalExpenses = 'site_additional_expenses';
  static const String siteBudget = 'site_budget';
  static const String siteChat = 'site_chat';
  static const String siteEdit = 'site_edit';

  static const List<String> topLevelModules = [
    dashboard,
    sites,
    employees,
    budget,
    chat,
    products,
    personal,
    roleManagement,
  ];

  static const List<String> siteSubModules = [
    siteSummary,
    siteTasks,
    siteLabour,
    siteMaterials,
    siteSubcontractors,
    siteAdditionalExpenses,
    siteBudget,
    siteChat,
    siteEdit,
  ];

  static const List<String> allModules = [
    ...topLevelModules,
    ...siteSubModules,
  ];

  static String getLabel(String key) {
    switch (key) {
      case dashboard:
        return 'Dashboard';
      case sites:
        return 'Sites';
      case employees:
        return 'Employees';
      case budget:
        return 'Company Budget';
      case chat:
        return 'Direct Chat';
      case products:
        return 'Products Catalog';
      case personal:
        return 'Personal Notes';
      case roleManagement:
        return 'Role & Access Control';
      case siteSummary:
        return 'Site Summary';
      case siteTasks:
        return 'Site Tasks';
      case siteLabour:
        return 'Labour Costs';
      case siteMaterials:
        return 'Material Invoices';
      case siteSubcontractors:
        return 'Subcontractors';
      case siteAdditionalExpenses:
        return 'Additional Expenses';
      case siteBudget:
        return 'Site Budget';
      case siteChat:
        return 'Site Chat';
      case siteEdit:
        return 'Edit Site Info';
      default:
        return key;
    }
  }

  static String getDescription(String key) {
    switch (key) {
      case dashboard:
        return 'Overview cards, overall spending metrics, and project status.';
      case sites:
        return 'List of all construction projects and sites.';
      case employees:
        return 'Directory of staff, engineers, and access assignments.';
      case budget:
        return 'Global company financial summary and budget allocations.';
      case chat:
        return 'Direct messaging with teammates.';
      case products:
        return 'Materials price list and item specs.';
      case personal:
        return 'Private workspace notes and folders.';
      case roleManagement:
        return 'Manage roles, custom employee roles, and permissions.';
      case siteSummary:
        return 'Received cash, total expenses, and balance for this site.';
      case siteTasks:
        return 'Project task checklist, progress, and assignments.';
      case siteLabour:
        return 'Daily worker hours, rates, and wage logs.';
      case siteMaterials:
        return 'Materials delivered, supplier invoices, and VAT.';
      case siteSubcontractors:
        return 'Contractor agreements and stage payouts.';
      case siteAdditionalExpenses:
        return 'Incidentals, equipment rentals, and extra costs.';
      case siteBudget:
        return 'Site-specific allocated income vs expenditures.';
      case siteChat:
        return 'Dedicated group conversation for this site team.';
      case siteEdit:
        return 'Change site name, dates, status, or assigned budget.';
      default:
        return '';
    }
  }

  static IconData getIcon(String key) {
    switch (key) {
      case dashboard:
        return Icons.dashboard_outlined;
      case sites:
        return Icons.business_outlined;
      case employees:
        return Icons.badge_outlined;
      case budget:
        return Icons.account_balance_wallet_outlined;
      case chat:
        return Icons.chat_outlined;
      case products:
        return Icons.inventory_2_outlined;
      case personal:
        return Icons.folder_shared_outlined;
      case roleManagement:
        return Icons.admin_panel_settings_outlined;
      case siteSummary:
        return Icons.assessment_outlined;
      case siteTasks:
        return Icons.check_box_outlined;
      case siteLabour:
        return Icons.engineering_outlined;
      case siteMaterials:
        return Icons.inventory_outlined;
      case siteSubcontractors:
        return Icons.handshake_outlined;
      case siteAdditionalExpenses:
        return Icons.receipt_long_outlined;
      case siteBudget:
        return Icons.account_balance_outlined;
      case siteChat:
        return Icons.forum_outlined;
      case siteEdit:
        return Icons.edit_note_outlined;
      default:
        return Icons.lock_outline;
    }
  }
}
