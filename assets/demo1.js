export default async function handler(req, res) {
  const supabaseUrl = 'https://nnrjievanuqlealabihr.supabase.co';
  const supabaseKey = 'YOUR_ANON_KEY';

  const response = await fetch(`${supabaseUrl}/rest/v1/vkb_accounts?select=*`, {
    headers: {
      'apikey': supabaseKey,
      'Authorization': `Bearer ${supabaseKey}`,
      'Content-Type': 'application/json'
    }
  });

  const data = await response.json();
  res.status(200).json(data);
}
