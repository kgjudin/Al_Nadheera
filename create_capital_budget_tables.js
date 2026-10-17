const { Client } = require('pg');

const client = new Client({
  host: 'aws-0-ap-southeast-1.pooler.supabase.com',
  port: 6543,
  user: 'postgres.iahwyfbkdmppgmbhteyt',
  password: 'Jd@9746521953',
  database: 'postgres',
});

async function run() {
  await client.connect();
  console.log('Connected to Supabase PostgreSQL...');

  const sql = `
    CREATE TABLE IF NOT EXISTS public.capital_banks (
        id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
        bank_name TEXT NOT NULL,
        account_number TEXT,
        balance NUMERIC NOT NULL DEFAULT 0,
        notes TEXT,
        created_at TIMESTAMPTZ DEFAULT NOW(),
        updated_at TIMESTAMPTZ DEFAULT NOW()
    );

    ALTER TABLE public.capital_banks ENABLE ROW LEVEL SECURITY;
    DROP POLICY IF EXISTS "Allow authenticated full access to capital_banks" ON public.capital_banks;
    CREATE POLICY "Allow authenticated full access to capital_banks" ON public.capital_banks FOR ALL TO authenticated USING (true) WITH CHECK (true);

    CREATE TABLE IF NOT EXISTS public.capital_bank_transactions (
        id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
        bank_id UUID REFERENCES public.capital_banks(id) ON DELETE CASCADE,
        bank_name TEXT NOT NULL,
        transaction_type TEXT NOT NULL, -- 'deposit', 'withdrawal', 'site_allocation', 'company_allocation'
        amount NUMERIC NOT NULL,
        balance_after NUMERIC NOT NULL DEFAULT 0,
        reference_title TEXT,
        site_id UUID REFERENCES public.sites(id) ON DELETE SET NULL,
        income_section_id UUID REFERENCES public.income_sections(id) ON DELETE SET NULL,
        notes TEXT,
        date DATE NOT NULL DEFAULT CURRENT_DATE,
        created_by TEXT,
        created_at TIMESTAMPTZ DEFAULT NOW()
    );

    ALTER TABLE public.capital_bank_transactions ENABLE ROW LEVEL SECURITY;
    DROP POLICY IF EXISTS "Allow authenticated full access to capital_bank_transactions" ON public.capital_bank_transactions;
    CREATE POLICY "Allow authenticated full access to capital_bank_transactions" ON public.capital_bank_transactions FOR ALL TO authenticated USING (true) WITH CHECK (true);

    ALTER TABLE public.site_budget_transactions ADD COLUMN IF NOT EXISTS bank_id UUID REFERENCES public.capital_banks(id) ON DELETE SET NULL;
    ALTER TABLE public.site_budget_transactions ADD COLUMN IF NOT EXISTS bank_name TEXT;

    ALTER TABLE public.income_sections ADD COLUMN IF NOT EXISTS bank_id UUID REFERENCES public.capital_banks(id) ON DELETE SET NULL;
    ALTER TABLE public.income_sections ADD COLUMN IF NOT EXISTS bank_name TEXT;

    NOTIFY pgrst, 'reload schema';
  `;

  await client.query(sql);
  console.log('Successfully created capital_banks and capital_bank_transactions tables!');
  await client.end();
}

run().catch((e) => {
  console.error('Migration failed:', e);
  client.end();
});
