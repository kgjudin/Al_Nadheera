-- AL NADHEERA CONSTRUCTION - Database Schema
-- Run this in Supabase SQL Editor

-- Enable UUID extension if not already enabled
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 1. Sites Table
CREATE TABLE public.sites (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL,
    code TEXT,
    client_name TEXT,
    location TEXT,
    start_date DATE,
    status TEXT DEFAULT 'Active',
    assigned_budget NUMERIC DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. Site Summary Table
CREATE TABLE public.site_summary (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    site_id UUID REFERENCES public.sites(id) ON DELETE CASCADE,
    date DATE NOT NULL,
    received_amount NUMERIC DEFAULT 0,
    cash_expenses NUMERIC DEFAULT 0,
    amount NUMERIC DEFAULT 0,
    balance NUMERIC DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. Labour Costs Table
CREATE TABLE public.labour_costs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    site_id UUID REFERENCES public.sites(id) ON DELETE CASCADE,
    date DATE NOT NULL,
    labour TEXT NOT NULL,
    quantity NUMERIC DEFAULT 0,
    rate NUMERIC DEFAULT 0,
    amount NUMERIC GENERATED ALWAYS AS (quantity * rate) STORED,
    pending NUMERIC DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 4. Material Costs Table
CREATE TABLE public.material_costs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    site_id UUID REFERENCES public.sites(id) ON DELETE CASCADE,
    date DATE NOT NULL,
    supplier_name TEXT NOT NULL,
    invoice_number TEXT,
    invoice_amount NUMERIC DEFAULT 0,
    vat_amount NUMERIC DEFAULT 0,
    remarks TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 5. Subcontractors Table
CREATE TABLE public.subcontractors (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    site_id UUID REFERENCES public.sites(id) ON DELETE CASCADE,
    date DATE NOT NULL,
    supplier_name TEXT NOT NULL,
    invoice_number TEXT,
    invoice_amount NUMERIC DEFAULT 0,
    vat_amount NUMERIC DEFAULT 0,
    remark TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 6. Additional Expenses Table
CREATE TABLE public.additional_expenses (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    site_id UUID REFERENCES public.sites(id) ON DELETE CASCADE,
    date DATE NOT NULL,
    expense_title TEXT NOT NULL,
    amount NUMERIC DEFAULT 0,
    remarks TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 7. Employees Table
CREATE TABLE public.employees (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    employee_id TEXT UNIQUE,
    name TEXT NOT NULL,
    phone TEXT,
    email TEXT,
    role TEXT,
    joining_date DATE,
    assigned_site_id UUID REFERENCES public.sites(id) ON DELETE SET NULL,
    status TEXT DEFAULT 'Active',
    profile_image_url TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 8. Tasks Table
CREATE TABLE public.tasks (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    site_id UUID REFERENCES public.sites(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    description TEXT,
    assigned_employee_id UUID REFERENCES public.employees(id) ON DELETE SET NULL,
    start_date DATE,
    due_date DATE,
    status TEXT DEFAULT 'Pending',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 9. Site Budget Table
CREATE TABLE public.site_budget (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    site_id UUID REFERENCES public.sites(id) ON DELETE CASCADE,
    income_came NUMERIC DEFAULT 0,
    income_spend NUMERIC DEFAULT 0,
    balance NUMERIC GENERATED ALWAYS AS (income_came - income_spend) STORED,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 10. Chat Messages Table
CREATE TABLE public.chat_messages (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    site_id UUID REFERENCES public.sites(id) ON DELETE CASCADE,
    receiver_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    sender_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    message TEXT,
    message_type TEXT DEFAULT 'text',
    media_url TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 11. Personal Folders Table
CREATE TABLE public.personal_folders (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 12. Personal Notes Table
CREATE TABLE public.personal_notes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    folder_id UUID REFERENCES public.personal_folders(id) ON DELETE CASCADE,
    title TEXT,
    content TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 13. Personal Note Images Table
CREATE TABLE public.personal_note_images (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    note_id UUID REFERENCES public.personal_notes(id) ON DELETE CASCADE,
    image_url TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 14. Products Table
CREATE TABLE IF NOT EXISTS public.products (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL,
    unit TEXT,
    price NUMERIC DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 15. Income Sections Table
CREATE TABLE IF NOT EXISTS public.income_sections (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    title TEXT NOT NULL,
    date DATE NOT NULL,
    amount NUMERIC DEFAULT 0,
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 16. Income Expenses Table
CREATE TABLE IF NOT EXISTS public.income_expenses (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    income_id UUID REFERENCES public.income_sections(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    date DATE NOT NULL,
    amount NUMERIC DEFAULT 0,
    category TEXT,
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- RLS POLICIES (Row Level Security)

-- Enable RLS on all tables
ALTER TABLE public.sites ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.site_summary ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.labour_costs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.material_costs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.subcontractors ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.additional_expenses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.employees ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tasks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.site_budget ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chat_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.personal_folders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.personal_notes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.personal_note_images ENABLE ROW LEVEL SECURITY;

-- For this application, assuming any authenticated user (employee/admin) can read/write site data:
CREATE POLICY "Allow authenticated full access to sites" ON public.sites FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Allow authenticated full access to site_summary" ON public.site_summary FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Allow authenticated full access to labour_costs" ON public.labour_costs FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Allow authenticated full access to material_costs" ON public.material_costs FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Allow authenticated full access to subcontractors" ON public.subcontractors FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Allow authenticated full access to additional_expenses" ON public.additional_expenses FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Allow authenticated full access to employees" ON public.employees FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Allow authenticated full access to tasks" ON public.tasks FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Allow authenticated full access to site_budget" ON public.site_budget FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Allow authenticated full access to chat_messages" ON public.chat_messages FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- Personal data should ONLY be accessible to the owner
CREATE POLICY "Users can manage their own folders" ON public.personal_folders FOR ALL TO authenticated USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
-- Notes policy requires checking the folder ownership (can be simplified if user_id is on notes, but we check via folder_id)
-- Or we just assume the API enforces it, but for RLS:
CREATE POLICY "Users can manage their own notes" ON public.personal_notes FOR ALL TO authenticated USING (
  EXISTS (SELECT 1 FROM public.personal_folders f WHERE f.id = folder_id AND f.user_id = auth.uid())
);
CREATE POLICY "Users can manage their own note images" ON public.personal_note_images FOR ALL TO authenticated USING (
  EXISTS (
    SELECT 1 FROM public.personal_notes n 
    JOIN public.personal_folders f ON n.folder_id = f.id 
    WHERE n.id = note_id AND f.user_id = auth.uid()
  )
);

-- STORAGE BUCKETS (If you are running this from SQL Editor)
INSERT INTO storage.buckets (id, name, public) VALUES ('profile-images', 'profile-images', true) ON CONFLICT DO NOTHING;
INSERT INTO storage.buckets (id, name, public) VALUES ('chat-media', 'chat-media', true) ON CONFLICT DO NOTHING;
INSERT INTO storage.buckets (id, name, public) VALUES ('personal-data', 'personal-data', false) ON CONFLICT DO NOTHING;

-- Storage Policies
CREATE POLICY "Public profile images" ON storage.objects FOR SELECT TO public USING (bucket_id = 'profile-images');
CREATE POLICY "Auth profile images upload" ON storage.objects FOR INSERT TO authenticated WITH CHECK (bucket_id = 'profile-images');
CREATE POLICY "Auth chat media access" ON storage.objects FOR SELECT TO authenticated USING (bucket_id = 'chat-media');
CREATE POLICY "Auth chat media upload" ON storage.objects FOR INSERT TO authenticated WITH CHECK (bucket_id = 'chat-media');

CREATE POLICY "Users own personal data access" ON storage.objects FOR SELECT TO authenticated USING (bucket_id = 'personal-data' AND (auth.uid() = owner));
CREATE POLICY "Users own personal data upload" ON storage.objects FOR INSERT TO authenticated WITH CHECK (bucket_id = 'personal-data' AND (auth.uid() = owner));

-- Realtime Setup
ALTER PUBLICATION supabase_realtime ADD TABLE public.chat_messages;
