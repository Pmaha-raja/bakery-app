export default async function handler(req, res) {
  const supabaseUrl = 'https://nnrjievanuqlealabihr.supabase.co';
  const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im5ucmppZXZhbnVxbGVhbGFiaWhyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODA0ODgzOTMsImV4cCI6MjA5NjA2NDM5M30.jz60L6ZQlPHmj22XkDGIxL1WMYEYHpkhYsKyQ8w3has';

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
