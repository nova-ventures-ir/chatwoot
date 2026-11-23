import { frontendURL } from './URLHelper';

const EMBED_MODE_KEY = 'cw_embed_mode';
const EMBED_ACCOUNT_KEY = 'cw_embed_account_id';

const BLOCKED_ROUTE_NAMES = new Set([
  'shopify_select_account',
  'onboarding_account_details',
  'no_accounts',
]);

export const isEmbedMode = () => sessionStorage.getItem(EMBED_MODE_KEY) === '1';

export const embedAccountId = () => sessionStorage.getItem(EMBED_ACCOUNT_KEY);

export const rememberEmbedMode = to => {
  if (to?.query?.embed !== '1') return;

  sessionStorage.setItem(EMBED_MODE_KEY, '1');
  if (to.params?.accountId) {
    sessionStorage.setItem(EMBED_ACCOUNT_KEY, String(to.params.accountId));
  }
};

const embedHome = accountId => ({
  path: frontendURL(`accounts/${accountId}/conversations`),
  query: { embed: '1' },
});

export const enforceEmbedRoute = (to, next) => {
  if (!isEmbedMode()) return false;

  const lockedAccountId = embedAccountId();
  const routeAccountId = to.params?.accountId
    ? String(to.params.accountId)
    : '';
  const switchesAccount = Boolean(
    lockedAccountId && routeAccountId && routeAccountId !== lockedAccountId
  );
  const blocked = BLOCKED_ROUTE_NAMES.has(to.name) || switchesAccount;
  if (!blocked) return false;

  const accountId = lockedAccountId || routeAccountId;
  if (!accountId) return false;

  next(embedHome(accountId));
  return true;
};
