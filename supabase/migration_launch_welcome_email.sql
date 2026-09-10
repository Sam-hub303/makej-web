-- ═══════════════════════════════════════════════════════════════════════════
-- PODĚKOVÁNÍ ZA ZAPSÁNÍ NA ČEKACÍ LIST (launch_emails → Resend)
-- ───────────────────────────────────────────────────────────────────────────
-- Spuštěno v projektu cxegfwfbgcgpwerfbvra jako migrace
-- `launch_emails_podekovani_pres_resend` (2026-09-09). Tenhle soubor je kopie
-- pro repo, aby bylo dohledatelné, co v databázi běží.
--
-- JAK TO CHODÍ: web zavolá RPC join_launch_list → INSERT do launch_emails →
-- AFTER INSERT trigger → net.http_post na api.resend.com → e-mail.
--
-- PROČ PŘÍMO Z DATABÁZE, a ne přes Edge Function: je to jeden HTTP požadavek.
-- Edge Function by znamenala další nasazovanou část, druhé místo pro tajemství
-- a další místo, kde se dá něco rozbít. Až budeme posílat víc druhů e-mailů,
-- vyplatí se to přesunout do funkce; na jeden transakční e-mail ne.
--
-- DUPLICITY: opakovaný e-mail končí v join_launch_list na `on conflict do
-- nothing`, takže žádný INSERT → trigger se nespustí → druhý e-mail nechodí.
-- Ověřeno: druhé odeslání téže adresy nevygenerovalo žádný požadavek.
--
-- KLÍČ: leží v Supabase Vaultu pod jménem `resend_api_key`. Vloží se jednou,
-- ručně, a NIKDY nepatří do repa:
--
--   select vault.create_secret('re_…', 'resend_api_key', 'Resend pro odchozí maily');
--
-- Bez klíče funkce jen zaloguje varování a zápis proběhne normálně dál.
--
-- ODESÍLATEL: ahoj@makej.eu. Doména makej.eu musí být v Resendu ověřená
-- (SPF/DKIM), jinak Resend odmítne s 403.
--
-- KONTROLA ODESLÁNÍ: select status_code, content from net._http_response
--                    order by created desc limit 10;
-- ═══════════════════════════════════════════════════════════════════════════

create extension if not exists pg_net with schema extensions;

create or replace function public.launch_email_podekovani()
returns trigger
language plpgsql
security definer
set search_path = public, net, vault, extensions
as $fn$
declare
  v_klic text;
  v_html text;
begin
  select decrypted_secret into v_klic
    from vault.decrypted_secrets
   where name = 'resend_api_key';

  if v_klic is null or btrim(v_klic) = '' then
    raise warning 'launch_email_podekovani: ve Vaultu chybí resend_api_key, e-mail pro % neodeslán', new.email;
    return null;
  end if;

  v_html := $html$<!DOCTYPE html>
<html lang="cs">
<head><meta charset="UTF-8" /><meta name="viewport" content="width=device-width, initial-scale=1.0" /><title>Seš na seznamu — Makej</title></head>
<body style="margin:0;padding:0;background:#ffffff;font-family:'Plus Jakarta Sans',Arial,Helvetica,sans-serif;color:#0a0d2e;">
  <table width="100%" cellpadding="0" cellspacing="0" border="0" style="background:#ffffff;padding:32px 16px;">
    <tr><td align="center">
      <table width="100%" cellpadding="0" cellspacing="0" border="0" style="max-width:560px;background:#ffffff;border:1px solid #e8ebf7;border-radius:20px;overflow:hidden;">

        <tr>
          <td style="background:#eef0fd;padding:34px 40px 40px;text-align:center;">
            <div style="font-size:20px;font-weight:800;letter-spacing:-0.3px;color:#0020f6;">Makej</div>
            <h1 style="margin:26px 0 0;font-size:30px;line-height:1.2;font-weight:800;color:#0a0d2e;">Seš na seznamu!</h1>
            <p style="margin:16px 0 0;font-size:15px;line-height:1.6;color:#6b7394;">
              Až Makej spustíme, dáme ti vědět mezi prvními. Do té doby od nás nic nechodí.
            </p>
          </td>
        </tr>

        <tr>
          <td style="padding:34px 40px 0;">
            <table width="100%" cellpadding="0" cellspacing="0" border="0" style="border:2px dashed #b9c2ff;border-radius:14px;">
              <tr><td style="padding:24px 22px;text-align:center;">
                <div style="font-size:11px;font-weight:800;letter-spacing:1.6px;color:#0020f6;">ZAKLÁDAJÍCÍ ČLEN</div>
                <div style="margin-top:12px;font-size:19px;font-weight:800;line-height:1.3;color:#0a0d2e;">Dokonči předregistraci a startuješ s náskokem</div>
                <p style="margin:12px 0 0;font-size:13.5px;line-height:1.65;color:#6b7394;">
                  Kdo je u toho od začátku, začíná s lepšími podmínkami než lidi, co přijdou až po spuštění. Zabere to minutu — stačí jméno a heslo.
                </p>
              </td></tr>
            </table>
          </td>
        </tr>

        <tr>
          <td style="padding:26px 40px 30px;text-align:center;">
            <table cellpadding="0" cellspacing="0" border="0" align="center"><tr><td align="center" style="border-radius:999px;background-color:#0020f6;background-image:linear-gradient(135deg,#2a45ff,#0020f6);">
              <a href="https://makej.eu/#predregistrace" style="display:inline-block;padding:16px 34px;color:#ffffff;text-decoration:none;font-size:16px;font-weight:700;letter-spacing:0.2px;">Dokončit předregistraci</a>
            </td></tr></table>
            <p style="margin:28px 0 0;font-size:14px;line-height:1.7;color:#4b5578;">
              <strong style="color:#0a0d2e;">Makej</strong> je apka na brigády ve tvém okolí — swajpuješ nabídky, matchuješ se s firmami a jdeš makat. Bez CV, bez pohovorů, zdarma.
            </p>
          </td>
        </tr>

        <tr><td style="padding:0 40px;"><div style="height:1px;line-height:1px;font-size:0;background:#e8ebf7;">&nbsp;</div></td></tr>

        <tr>
          <td style="padding:20px 40px 28px;text-align:center;">
            <p style="margin:0;font-size:12px;line-height:1.75;color:#8a93b2;">
              Makej s náma s.r.o. · Brno · IČO 29900590<br/>
              Adresu jsi nechal/a na <a href="https://makej.eu" style="color:#0020f6;text-decoration:none;">makej.eu</a>. Pokud to nebyl/a ty, stačí e-mail ignorovat.
            </p>
          </td>
        </tr>

      </table>
    </td></tr>
  </table>
</body>
</html>$html$;

  perform net.http_post(
    url     := 'https://api.resend.com/emails',
    headers := jsonb_build_object(
                 'Authorization', 'Bearer ' || v_klic,
                 'Content-Type',  'application/json'
               ),
    body    := jsonb_build_object(
                 'from',    'Makej <ahoj@makej.eu>',
                 'to',      new.email,
                 'subject', 'Seš na seznamu!',
                 'html',    v_html
               )
  );

  return null;

exception when others then
  -- Zápis do seznamu má přednost před e-mailem: nikdy kvůli odeslání nespadne.
  raise warning 'launch_email_podekovani: odeslání pro % selhalo — %', new.email, sqlerrm;
  return null;
end;
$fn$;

comment on function public.launch_email_podekovani() is
  'AFTER INSERT na launch_emails: přes pg_net pošle Resendem poděkování. Klíč z Vaultu (resend_api_key). Chyba odeslání nikdy neshodí zápis.';

drop trigger if exists launch_emails_podekovani on public.launch_emails;
create trigger launch_emails_podekovani
  after insert on public.launch_emails
  for each row execute function public.launch_email_podekovani();
