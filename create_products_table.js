const { Client } = require('pg');

const connectionString = 'postgresql://postgres:Jd%409746521953@db.iahwyfbkdmppgmbhteyt.supabase.co:5432/postgres';

async function createProductsTable() {
  const client = new Client({ connectionString });
  try {
    await client.connect();
    console.log('Connected to Supabase PostgreSQL...');

    await client.query(`
      CREATE TABLE IF NOT EXISTS public.products (
          id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
          name TEXT NOT NULL,
          unit TEXT,
          price NUMERIC DEFAULT 0,
          created_at TIMESTAMPTZ DEFAULT NOW(),
          updated_at TIMESTAMPTZ DEFAULT NOW()
      );

      ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;

      DROP POLICY IF EXISTS "Allow authenticated full access to products" ON public.products;
      CREATE POLICY "Allow authenticated full access to products" ON public.products FOR ALL TO authenticated USING (true) WITH CHECK (true);

      DROP POLICY IF EXISTS "Allow anon full access to products" ON public.products;
      CREATE POLICY "Allow anon full access to products" ON public.products FOR ALL TO anon USING (true) WITH CHECK (true);

      NOTIFY pgrst, 'reload schema';
    `);
    console.log('Successfully created products table and applied RLS policies!');
  } catch (error) {
    console.error('Table creation failed:', error);
  } finally {
    await client.end();
  }
}

createProductsTable();
