import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import {
  collection,
  query,
  where,
  getDocs,
  doc,
  addDoc,
  updateDoc,
  deleteDoc,
  serverTimestamp,
  Timestamp,
  onSnapshot,
} from 'firebase/firestore'
import { db } from '@/lib/firebase/config'
import type { Connection, ConnectionStatusResult } from '@/lib/types'
import { useEffect, useState } from 'react'

// Parse connection document
function parseConnection(doc: any): Connection {
  const data = doc.data()
  return {
    id: doc.id,
    fromUID: data.fromUID,
    toUID: data.toUID,
    participants: data.participants || [],
    participantUsernames: data.participantUsernames || {},
    status: data.status,
    createdAt: (data.createdAt as Timestamp)?.toDate() || new Date(),
    respondedAt: data.respondedAt ? (data.respondedAt as Timestamp).toDate() : undefined,
  }
}

// Real-time connections listener
export function useConnections(uid: string | undefined) {
  const [connections, setConnections] = useState<Connection[]>([])
  const [incomingRequests, setIncomingRequests] = useState<Connection[]>([])
  const [outgoingRequests, setOutgoingRequests] = useState<Connection[]>([])
  const [isLoading, setIsLoading] = useState(true)

  useEffect(() => {
    if (!uid) {
      setConnections([])
      setIncomingRequests([])
      setOutgoingRequests([])
      setIsLoading(false)
      return
    }

    setIsLoading(true)

    // Accepted connections
    const connectionsQuery = query(
      collection(db, 'connectionRequests'),
      where('participants', 'array-contains', uid),
      where('status', '==', 'accepted')
    )

    const connectionsUnsub = onSnapshot(connectionsQuery, (snapshot) => {
      setConnections(snapshot.docs.map(parseConnection))
    })

    // Incoming requests
    const incomingQuery = query(
      collection(db, 'connectionRequests'),
      where('toUID', '==', uid),
      where('status', '==', 'pending')
    )

    const incomingUnsub = onSnapshot(incomingQuery, (snapshot) => {
      setIncomingRequests(
        snapshot.docs
          .map(parseConnection)
          .sort((a, b) => b.createdAt.getTime() - a.createdAt.getTime())
      )
    })

    // Outgoing requests
    const outgoingQuery = query(
      collection(db, 'connectionRequests'),
      where('fromUID', '==', uid),
      where('status', '==', 'pending')
    )

    const outgoingUnsub = onSnapshot(outgoingQuery, (snapshot) => {
      setOutgoingRequests(snapshot.docs.map(parseConnection))
      setIsLoading(false)
    })

    return () => {
      connectionsUnsub()
      incomingUnsub()
      outgoingUnsub()
    }
  }, [uid])

  // Get connection status with a specific user
  const getConnectionStatus = (targetUID: string): ConnectionStatusResult => {
    const connected = connections.find((c) => c.participants.includes(targetUID))
    if (connected) return { type: 'connected', connection: connected }

    const outgoing = outgoingRequests.find((r) => r.toUID === targetUID)
    if (outgoing) return { type: 'pendingOutgoing', connection: outgoing }

    const incoming = incomingRequests.find((r) => r.fromUID === targetUID)
    if (incoming) return { type: 'pendingIncoming', connection: incoming }

    return { type: 'none' }
  }

  return {
    connections,
    incomingRequests,
    outgoingRequests,
    isLoading,
    getConnectionStatus,
  }
}

// Send connection request
export function useSendConnectionRequest() {
  const queryClient = useQueryClient()

  return useMutation({
    mutationFn: async ({
      fromUID,
      fromUsername,
      toUID,
      toUsername,
    }: {
      fromUID: string
      fromUsername: string
      toUID: string
      toUsername: string
    }) => {
      const data = {
        fromUID,
        toUID,
        participants: [fromUID, toUID],
        participantUsernames: {
          [fromUID]: fromUsername,
          [toUID]: toUsername,
        },
        status: 'pending',
        createdAt: serverTimestamp(),
      }

      await addDoc(collection(db, 'connectionRequests'), data)
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['connections'] })
    },
  })
}

// Accept connection request
export function useAcceptConnectionRequest() {
  const queryClient = useQueryClient()

  return useMutation({
    mutationFn: async (requestId: string) => {
      await updateDoc(doc(db, 'connectionRequests', requestId), {
        status: 'accepted',
        respondedAt: serverTimestamp(),
      })
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['connections'] })
    },
  })
}

// Reject connection request
export function useRejectConnectionRequest() {
  const queryClient = useQueryClient()

  return useMutation({
    mutationFn: async (requestId: string) => {
      await updateDoc(doc(db, 'connectionRequests', requestId), {
        status: 'rejected',
        respondedAt: serverTimestamp(),
      })
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['connections'] })
    },
  })
}

// Withdraw connection request
export function useWithdrawConnectionRequest() {
  const queryClient = useQueryClient()

  return useMutation({
    mutationFn: async (requestId: string) => {
      await deleteDoc(doc(db, 'connectionRequests', requestId))
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['connections'] })
    },
  })
}

// Remove connection
export function useRemoveConnection() {
  const queryClient = useQueryClient()

  return useMutation({
    mutationFn: async (requestId: string) => {
      await deleteDoc(doc(db, 'connectionRequests', requestId))
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['connections'] })
    },
  })
}
