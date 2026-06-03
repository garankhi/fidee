import axios from 'axios';
import { User } from './adminData';

const API_BASE_URL = import.meta.env.VITE_API_URL || 'http://localhost:5000/api';

// Cấu hình instance Axios cao cấp
const api = axios.create({
  baseURL: API_BASE_URL,
  headers: {
    'Content-Type': 'application/json',
  },
});

// Interceptor tự động tiêm JWT Token của Admin vào mọi yêu cầu gửi đi
api.interceptors.request.use((config) => {
  const token = typeof window !== 'undefined' && window.localStorage
    ? window.localStorage.getItem('admin_token')
    : null;
  if (token) {
    config.headers.Authorization = token;
  }
  return config;
});

/**
 * Fetch all users from the backend API.
 */
export async function fetchUsers(): Promise<User[]> {
  const response = await api.get<User[]>('/admin/users');
  return response.data;
}

/**
 * Update user details in the backend API.
 */
export async function updateUserData(userId: string, data: Partial<User>): Promise<User> {
  const response = await api.put<User>(`/admin/users/${userId}`, data);
  return response.data;
}
