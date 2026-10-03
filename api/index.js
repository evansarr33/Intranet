// Same-origin proxy from Vercel to the authenticated Supabase Edge Function.
// The service key and session signing secret remain in Supabase; Vercel needs no secrets.
const SUPABASE_URL = 'https://kpcprbhsaxdlwftofrym.supabase.co';
const SUPABASE_PUBLISHABLE_KEY = 'sb_publishable_2eyDXjK_UK8mxZJdNp1bbw_jedfJBhQ';
const EDGE_FUNCTION = `${SUPABASE_URL}/functions/v1/noria`;

function reply(res,status,data){
  res.statusCode=status;
  res.setHeader('Content-Type','application/json; charset=utf-8');
  res.setHeader('Cache-Control','no-store');
  res.end(JSON.stringify(data));
}

async function body(req){
  let text='';
  for await(const chunk of req){
    text+=chunk;
    if(text.length>7200000)throw Object.assign(new Error('Requête trop volumineuse.'),{status:413});
  }
  try{return JSON.parse(text||'{}')}
  catch{throw Object.assign(new Error('Requête invalide.'),{status:400})}
}

module.exports=async function handler(req,res){
  try{
    const incoming=new URL(req.url,`https://${req.headers.host||'localhost'}`);
    const action=incoming.searchParams.get('action');
    if(!action)return reply(res,404,{error:'Action introuvable.'});

    const target=new URL(EDGE_FUNCTION);
    target.searchParams.set('action',action);
    const headers={apikey:SUPABASE_PUBLISHABLE_KEY};
    if(req.headers.cookie)headers.Cookie=req.headers.cookie;

    let requestBody;
    if(!['GET','HEAD'].includes(req.method)){
      headers['Content-Type']='application/json';
      requestBody=JSON.stringify(await body(req));
    }
    const upstream=await fetch(target,{method:req.method,headers,body:requestBody});
    const responseBody=await upstream.text();
    res.statusCode=upstream.status;
    res.setHeader('Content-Type',upstream.headers.get('content-type')||'application/json; charset=utf-8');
    res.setHeader('Cache-Control','no-store');
    const cookies=typeof upstream.headers.getSetCookie==='function'
      ?upstream.headers.getSetCookie()
      :(upstream.headers.get('set-cookie')?[upstream.headers.get('set-cookie')]:[]);
    if(cookies.length)res.setHeader('Set-Cookie',cookies);
    res.end(responseBody);
  }catch(error){
    console.error('[noria-proxy]',error?.message||error);
    reply(res,error?.status&&error.status<500?error.status:503,{
      error:error?.status&&error.status<500?error.message:'Le service est momentanément indisponible. Réessayez plus tard.'
    });
  }
};
