import { useEffect, useState } from "react";

function generateId() {
  return (Math.random() * 100000).toFixed();
}

export default function useClientId() {
  const [clientId, setClientId] = useState<string>();
  useEffect(() => {
    const hash = window.location.hash.substring(1);
    if (hash) {
      setClientId(hash);
    } else {
      const id = generateId();
      window.location.href = `#${id}`;
      setClientId(id);
    }
  }, []);
  return clientId;
}
