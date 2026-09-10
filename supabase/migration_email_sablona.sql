-- ═══════════════════════════════════════════════════════════════════════════
-- SPOLEČNÁ ŠABLONA ODCHOZÍCH E-MAILŮ (makej_email_html + html_escape)
-- ───────────────────────────────────────────────────────────────────────────
-- Migrace `makej_email_spolecna_sablona_a_logo` (2026-09-10).
--
-- PROČ: e-maily jsou dva (čekací list, registrace) a další přibudou. Obálka
-- žije tady, jednotlivé e-maily dodávají nadpis, podnadpis a vnitřek bílé
-- části. Bez toho by se každá změna vzhledu dělala dvakrát a časem rozešla.
--
-- LOGO JE TEXT, ne obrázek — a je to vědomý ústupek. Obrázek se servíroval
-- správně (HTTP 200, platný PNG), ale Seznam Email a řada dalších klientů
-- obrázky z cizích serverů ve výchozím stavu blokuje a příjemci zbyla ikona
-- rozbitého obrázku. Text dorazí vždycky.
--
-- Cenou je font: League Spartan je webový font a klienti @font-face zahazují,
-- takže se nápis vykreslí náhradním řezem (Arial Black / Helvetica). Ve stacku
-- ji uvádíme první kvůli těm pár klientům, kde je font v systému. Váha,
-- prostrkání i barva jsou podle navbaru, ať je to co nejblíž.
--
-- `logo-makej.png` v kořeni webu zůstává — vyrenderovaný z fontu webu, může se
-- hodit jinde (og:image). V e-mailu se nepoužívá.
-- ═══════════════════════════════════════════════════════════════════════════

create or replace function public.makej_email_html(
  p_nadpis    text,
  p_podnadpis text,
  p_telo      text
) returns text
language sql
immutable
as $$
  select replace(replace(replace($html$<!DOCTYPE html>
<html lang="cs">
<head><meta charset="UTF-8" /><meta name="viewport" content="width=device-width, initial-scale=1.0" /><title>Makej</title></head>
<body style="margin:0;padding:0;background:#ffffff;font-family:'Plus Jakarta Sans',Arial,Helvetica,sans-serif;color:#0a0d2e;">
  <table width="100%" cellpadding="0" cellspacing="0" border="0" style="background:#ffffff;padding:32px 16px;">
    <tr><td align="center">
      <table width="100%" cellpadding="0" cellspacing="0" border="0" style="max-width:560px;background:#ffffff;border:1px solid #e8ebf7;border-radius:20px;overflow:hidden;">

        <tr>
          <td style="background:#eef0fd;padding:34px 40px 40px;text-align:center;">
            <div style="font-family:'League Spartan','Arial Black','Helvetica Neue',Arial,sans-serif;font-size:32px;font-weight:900;letter-spacing:-1px;line-height:1;color:#0020f6;">Makej</div>
            <h1 style="margin:26px 0 0;font-size:30px;line-height:1.2;font-weight:800;color:#0a0d2e;">{{NADPIS}}</h1>
            <p style="margin:16px 0 0;font-size:15px;line-height:1.6;color:#6b7394;">{{PODNADPIS}}</p>
          </td>
        </tr>

        {{TELO}}

        <tr><td style="padding:0 40px;"><div style="height:1px;line-height:1px;font-size:0;background:#e8ebf7;">&nbsp;</div></td></tr>

        <tr>
          <td style="padding:20px 40px 28px;text-align:center;">
            <p style="margin:0;font-size:12px;line-height:1.75;color:#8a93b2;">
              Makej s náma s.r.o. · Brno · IČO 29900590<br/>
              Tenhle e-mail ti přišel, protože jsi svou adresu nechal/a na <a href="https://makej.eu" style="color:#0020f6;text-decoration:none;">makej.eu</a>.
            </p>
          </td>
        </tr>

      </table>
    </td></tr>
  </table>
</body>
</html>$html$, '{{NADPIS}}', p_nadpis), '{{PODNADPIS}}', p_podnadpis), '{{TELO}}', p_telo);
$$;

comment on function public.makej_email_html(text, text, text) is
  'Obálka odchozích e-mailů (logo, hlavička, patička). Vnitřek bílé části dodává volající jako HTML řádky tabulky.';

-- Text od uživatele (jméno) míří do HTML — bez tohohle by šlo e-mailem poslat
-- vlastní značky každému, kdo se zaregistruje pod jménem s „<".
create or replace function public.html_escape(p text)
returns text
language sql
immutable
as $$
  select replace(replace(replace(coalesce(p, ''), '&', '&amp;'), '<', '&lt;'), '>', '&gt;');
$$;
