import { PublicClientApplication, AccountInfo } from '@azure/msal-browser';
import { msalConfig, loginRequest, graphConfig, isOidcEnabled } from './authConfig';
import { AuthUser } from '../types';

let msalInstance: PublicClientApplication | null = null;

const initializeMsal = async () => {
  if (isOidcEnabled() && !msalInstance) {
    msalInstance = new PublicClientApplication(msalConfig);
    await msalInstance.initialize();
  }
};

initializeMsal();

export const getCurrentAccount = (): AccountInfo | null => {
  if (!msalInstance) return null;
  const accounts = msalInstance.getAllAccounts();
  return accounts.length > 0 ? accounts[0] : null;
};

export const login = async (): Promise<AccountInfo | null> => {
  if (!msalInstance) {
    throw new Error('OIDC authentication is disabled');
  }
  try {
    const response = await msalInstance.loginPopup(loginRequest);
    return response.account;
  } catch (error: any) {
    if (error.errorCode === 'user_cancelled') {
      return null;
    }
    throw error;
  }
};

export const logout = async (): Promise<void> => {
  if (!msalInstance) return;
  const account = getCurrentAccount();
  if (account) {
    await msalInstance.logoutPopup({ account });
  }
};

export const getUserInfo = async (): Promise<AuthUser | null> => {
  if (!msalInstance) return null;
  const account = getCurrentAccount();
  if (!account) return null;

  try {
    const tokenResponse = await msalInstance.acquireTokenSilent({
      ...loginRequest,
      account: account,
    });

    const response = await fetch(graphConfig.graphMeEndpoint, {
      headers: {
        Authorization: `Bearer ${tokenResponse.accessToken}`,
      },
    });

    if (!response.ok) {
      throw new Error('Failed to fetch user info');
    }

    const userData = await response.json();
    
    return {
      id: userData.id || account.homeAccountId,
      name: userData.displayName || account.name || 'User',
      email: userData.mail || userData.userPrincipalName || account.username,
    };
  } catch (error) {
    return {
      id: account.homeAccountId,
      name: account.name || 'User',
      email: account.username,
    };
  }
};

export const handleRedirectPromise = async (): Promise<AccountInfo | null> => {
  if (!msalInstance) return null;
  try {
    const response = await msalInstance.handleRedirectPromise();
    return response?.account || null;
  } catch (error) {
    console.error('Redirect error:', error);
    return null;
  }
};

