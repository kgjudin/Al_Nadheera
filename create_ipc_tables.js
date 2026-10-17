const { Client } = require('pg');

const client = new Client({
  host: 'aws-0-ap-southeast-1.pooler.supabase.com',
  port: 6543,
  user: 'postgres.iahwyfbkdmppgmbhteyt',
  password: 'Jd@9746521953',
  database: 'postgres',
});

async function run() {
  try {
    await client.connect();
    console.log('Connected to Supabase PostgreSQL...');

    const sql = `
      -- 1. Create ipc_documents table
      CREATE TABLE IF NOT EXISTS public.ipc_documents (
          id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
          document_number TEXT,
          project_name TEXT NOT NULL,
          client_name TEXT,
          date DATE DEFAULT CURRENT_DATE,
          status TEXT DEFAULT 'Draft',
          total_amount NUMERIC DEFAULT 0,
          items JSONB DEFAULT '[]'::jsonb,
          notes TEXT,
          created_at TIMESTAMPTZ DEFAULT NOW(),
          updated_at TIMESTAMPTZ DEFAULT NOW()
      );

      ALTER TABLE public.ipc_documents ENABLE ROW LEVEL SECURITY;
      DROP POLICY IF EXISTS "Allow authenticated full access to ipc_documents" ON public.ipc_documents;
      CREATE POLICY "Allow authenticated full access to ipc_documents" ON public.ipc_documents FOR ALL TO authenticated USING (true) WITH CHECK (true);
      DROP POLICY IF EXISTS "Allow anon full access to ipc_documents" ON public.ipc_documents;
      CREATE POLICY "Allow anon full access to ipc_documents" ON public.ipc_documents FOR ALL TO anon USING (true) WITH CHECK (true);

      -- 2. Create ipc_items table
      CREATE TABLE IF NOT EXISTS public.ipc_items (
          id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
          ipc_id UUID REFERENCES public.ipc_documents(id) ON DELETE CASCADE,
          item_type TEXT DEFAULT 'item', -- 'heading', 'subheading', 'item'
          item_number TEXT,
          description TEXT NOT NULL,
          unit TEXT,
          quantity NUMERIC DEFAULT 0,
          rate NUMERIC DEFAULT 0,
          amount NUMERIC DEFAULT 0,
          sort_order INT DEFAULT 0,
          class_name TEXT,
          submodule_name TEXT,
          product_id UUID REFERENCES public.products(id) ON DELETE SET NULL,
          created_at TIMESTAMPTZ DEFAULT NOW()
      );

      ALTER TABLE public.ipc_items ENABLE ROW LEVEL SECURITY;
      DROP POLICY IF EXISTS "Allow authenticated full access to ipc_items" ON public.ipc_items;
      CREATE POLICY "Allow authenticated full access to ipc_items" ON public.ipc_items FOR ALL TO authenticated USING (true) WITH CHECK (true);
      DROP POLICY IF EXISTS "Allow anon full access to ipc_items" ON public.ipc_items;
      CREATE POLICY "Allow anon full access to ipc_items" ON public.ipc_items FOR ALL TO anon USING (true) WITH CHECK (true);

      NOTIFY pgrst, 'reload schema';
    `;

    await client.query(sql);
    console.log('Successfully created ipc_documents and ipc_items tables and reloaded PostgREST cache!');
  } catch (err) {
    console.error('Error running SQL migration:', err);
  } finally {
    await client.end();
  }
}

run();
